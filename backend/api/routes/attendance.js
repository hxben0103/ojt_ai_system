const express = require('express');
const router = express.Router();
const { query } = require('../../config/db');

// Get all attendance records
router.get('/', async (req, res) => {
  try {
    const { student_id, date } = req.query;
    
    let sql = `
      SELECT a.*, u.full_name 
      FROM attendance a
      JOIN users u ON a.student_id = u.user_id
      WHERE 1=1
    `;
    const params = [];
    let paramCount = 1;

    if (student_id) {
      sql += ` AND a.student_id = $${paramCount}`;
      params.push(student_id);
      paramCount++;
    }

    if (date) {
      sql += ` AND a.date = $${paramCount}`;
      params.push(date);
      paramCount++;
    }

    sql += ' ORDER BY a.date DESC, a.time_in DESC';

    const result = await query(sql, params);
    res.json({ attendance: result.rows });
  } catch (error) {
    console.error('Get attendance error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get today's attendance for a student
router.get('/today/:studentId', async (req, res) => {
  try {
    const { studentId } = req.params;
    const today = new Date().toISOString().split('T')[0];
    
    const result = await query(
      `SELECT a.*, u.full_name 
       FROM attendance a
       JOIN users u ON a.student_id = u.user_id
       WHERE a.student_id = $1 AND a.date = $2`,
      [studentId, today]
    );
    
    if (result.rows.length > 0) {
      res.json({ attendance: result.rows[0] });
    } else {
      res.json({ attendance: null });
    }
  } catch (error) {
    console.error('Get today attendance error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create attendance record (Time In) - Using stored procedure
// Supports both legacy time_in and segment-based logging
router.post('/time-in', async (req, res) => {
  try {
    const { student_id, ojt_record_id, date, segment, time_in } = req.body;

    if (!student_id) {
      return res.status(400).json({ error: 'student_id is required' });
    }

    const currentDate = date || new Date().toISOString().split('T')[0];
    const currentTime = time_in || new Date().toTimeString().split(' ')[0].substring(0, 8); // HH:MM:SS format

    // Check if attendance record exists for this date
    const existingRecord = await query(
      'SELECT attendance_id FROM attendance WHERE student_id = $1 AND date = $2',
      [student_id, currentDate]
    );

    let attendanceId;
    let morningIn = null;
    let afternoonIn = null;
    let overtimeIn = null;
    let timeInValue = null;

    // Map segment to appropriate field
    if (segment) {
      switch (segment) {
        case 'MORNING_IN':
          morningIn = currentTime;
          break;
        case 'AFTERNOON_IN':
          afternoonIn = currentTime;
          break;
        case 'OVERTIME_IN':
          overtimeIn = currentTime;
          break;
        default:
          timeInValue = currentTime;
      }
    } else {
      // Legacy support: use time_in if no segment specified
      timeInValue = currentTime;
    }

    if (existingRecord.rows.length > 0) {
      // Update existing record
      attendanceId = existingRecord.rows[0].attendance_id;
      
      // Build update query dynamically based on which segment is being logged
      let updateFields = [];
      let updateValues = [];
      let paramCount = 1;

      if (morningIn !== null) {
        updateFields.push(`morning_in = $${paramCount}`);
        updateValues.push(morningIn);
        paramCount++;
      }
      if (afternoonIn !== null) {
        updateFields.push(`afternoon_in = $${paramCount}`);
        updateValues.push(afternoonIn);
        paramCount++;
      }
      if (overtimeIn !== null) {
        updateFields.push(`overtime_in = $${paramCount}`);
        updateValues.push(overtimeIn);
        paramCount++;
      }
      if (timeInValue !== null && !morningIn && !afternoonIn && !overtimeIn) {
        updateFields.push(`time_in = $${paramCount}`);
        updateValues.push(timeInValue);
        paramCount++;
      }

      if (updateFields.length === 0) {
        return res.status(400).json({ error: 'Invalid segment or time_in value' });
      }

      // Check if this segment is already logged (prevent duplicate)
      const checkRecord = await query(
        'SELECT morning_in, afternoon_in, overtime_in, time_in FROM attendance WHERE attendance_id = $1',
        [attendanceId]
      );
      const existing = checkRecord.rows[0];
      
      if ((morningIn && existing.morning_in) || 
          (afternoonIn && existing.afternoon_in) || 
          (overtimeIn && existing.overtime_in) ||
          (timeInValue && existing.time_in && !morningIn && !afternoonIn && !overtimeIn)) {
        return res.status(400).json({ 
          error: 'Time in already recorded for this segment',
          errors: [`${segment || 'time_in'} already exists for this date`]
        });
      }

      updateValues.push(attendanceId);
      const updateSql = `
        UPDATE attendance 
        SET ${updateFields.join(', ')}, updated_at = CURRENT_TIMESTAMP
        WHERE attendance_id = $${paramCount}
        RETURNING attendance_id
      `;
      
      await query(updateSql, updateValues);
    } else {
      // Create new record
      const result = await query(
        'SELECT create_attendance($1, $2, $3, NULL, $4, NULL, $5, NULL) as result',
        [student_id, currentDate, timeInValue || morningIn || afternoonIn || overtimeIn, morningIn, afternoonIn]
      );

      const response = result.rows[0].result;

      if (!response.success) {
        return res.status(400).json({
          error: 'Validation failed',
          errors: response.errors
        });
      }

      attendanceId = response.attendance_id;

      // If we need to set overtime_in, update it separately
      if (overtimeIn) {
        await query(
          'UPDATE attendance SET overtime_in = $1 WHERE attendance_id = $2',
          [overtimeIn, attendanceId]
        );
      }
    }

    // Get the updated/created attendance record
    const attendanceResult = await query(
      'SELECT get_attendance($1) as attendance',
      [attendanceId]
    );
    
    res.status(201).json({
      message: 'Time in recorded successfully',
      attendance: attendanceResult.rows[0].attendance
    });
  } catch (error) {
    console.error('Time in error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update attendance record (Time Out) - Using stored procedure
// Supports both legacy time_out and segment-based logging
router.put('/time-out', async (req, res) => {
  try {
    const { attendance_id, student_id, date, segment, time_out } = req.body;

    if (!time_out) {
      return res.status(400).json({ error: 'time_out is required' });
    }

    const currentTime = time_out || new Date().toTimeString().split(' ')[0].substring(0, 8); // HH:MM:SS format

    let attendanceId = attendance_id;

    // If attendance_id not provided, try to find by student_id and date
    if (!attendanceId && student_id && date) {
      const findResult = await query(
        'SELECT attendance_id FROM attendance WHERE student_id = $1 AND date = $2',
        [student_id, date]
      );
      if (findResult.rows.length > 0) {
        attendanceId = findResult.rows[0].attendance_id;
      } else {
        return res.status(404).json({ error: 'Attendance record not found for this date' });
      }
    }

    if (!attendanceId) {
      return res.status(400).json({ error: 'attendance_id or (student_id and date) is required' });
    }

    let morningOut = null;
    let afternoonOut = null;
    let overtimeOut = null;
    let timeOutValue = null;

    // Map segment to appropriate field
    if (segment) {
      switch (segment) {
        case 'MORNING_OUT':
          morningOut = currentTime;
          break;
        case 'AFTERNOON_OUT':
          afternoonOut = currentTime;
          break;
        case 'OVERTIME_OUT':
          overtimeOut = currentTime;
          break;
        default:
          timeOutValue = currentTime;
      }
    } else {
      // Legacy support: use time_out if no segment specified
      timeOutValue = currentTime;
    }

    // Check if this segment is already logged (prevent duplicate)
    const checkRecord = await query(
      'SELECT morning_out, afternoon_out, overtime_out, time_out FROM attendance WHERE attendance_id = $1',
      [attendanceId]
    );
    
    if (checkRecord.rows.length === 0) {
      return res.status(404).json({ error: 'Attendance record not found' });
    }

    const existing = checkRecord.rows[0];
    
    if ((morningOut && existing.morning_out) || 
        (afternoonOut && existing.afternoon_out) || 
        (overtimeOut && existing.overtime_out) ||
        (timeOutValue && existing.time_out && !morningOut && !afternoonOut && !overtimeOut)) {
      return res.status(400).json({ 
        error: 'Time out already recorded for this segment',
        errors: [`${segment || 'time_out'} already exists for this record`]
      });
    }

    // Build update query dynamically
    let updateFields = [];
    let updateValues = [];
    let paramCount = 1;

    if (morningOut !== null) {
      updateFields.push(`morning_out = $${paramCount}`);
      updateValues.push(morningOut);
      paramCount++;
    }
    if (afternoonOut !== null) {
      updateFields.push(`afternoon_out = $${paramCount}`);
      updateValues.push(afternoonOut);
      paramCount++;
    }
    if (overtimeOut !== null) {
      updateFields.push(`overtime_out = $${paramCount}`);
      updateValues.push(overtimeOut);
      paramCount++;
    }
    if (timeOutValue !== null && !morningOut && !afternoonOut && !overtimeOut) {
      updateFields.push(`time_out = $${paramCount}`);
      updateValues.push(timeOutValue);
      paramCount++;
    }

    if (updateFields.length === 0) {
      return res.status(400).json({ error: 'Invalid segment or time_out value' });
    }

    updateValues.push(attendanceId);
    const updateSql = `
      UPDATE attendance 
      SET ${updateFields.join(', ')}, updated_at = CURRENT_TIMESTAMP
      WHERE attendance_id = $${paramCount}
      RETURNING attendance_id
    `;
    
    await query(updateSql, updateValues);

    // Get the updated attendance record
    const attendanceResult = await query(
      'SELECT get_attendance($1) as attendance',
      [attendanceId]
    );
    
    res.json({
      message: 'Time out recorded successfully',
      attendance: attendanceResult.rows[0].attendance
    });
  } catch (error) {
    console.error('Time out error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get attendance summary - Using stored procedure
router.get('/summary', async (req, res) => {
  try {
    const { student_id } = req.query;

    if (student_id) {
      // Use stored procedure for single student
      const result = await query(
        'SELECT get_attendance_statistics($1, NULL, NULL) as statistics',
        [student_id]
      );
      
      // Get student name separately
      const studentResult = await query(
        'SELECT full_name FROM users WHERE user_id = $1',
        [student_id]
      );
      
      // Get last duty date
      const lastDutyResult = await query(
        'SELECT MAX(date) as last_duty_date FROM attendance WHERE student_id = $1',
        [student_id]
      );
      
      const stats = result.rows[0].statistics;
      const studentName = studentResult.rows[0]?.full_name || 'N/A';
      const lastDutyDate = lastDutyResult.rows[0]?.last_duty_date || null;
      
      res.json({ 
        summary: [{
          full_name: studentName,
          total_days: parseInt(stats.summary?.total_days || 0),
          total_hours: parseFloat(stats.summary?.total_hours || 0),
          avg_hours_per_day: parseFloat(stats.summary?.avg_hours_per_day || 0),
          last_duty_date: lastDutyDate ? lastDutyDate.toISOString().split('T')[0] : null
        }]
      });
    } else {
      // For multiple students, use view (keep existing logic for compatibility)
      const result = await query(
        'SELECT * FROM view_attendance_summary'
      );
      res.json({ summary: result.rows });
    }
  } catch (error) {
    console.error('Get summary error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get attendance summary by student ID (alternative endpoint)
router.get('/summary/:studentId', async (req, res) => {
  try {
    const { studentId } = req.params;

    const result = await query(
      'SELECT get_attendance_statistics($1, NULL, NULL) as statistics',
      [studentId]
    );
    
    const studentResult = await query(
      'SELECT full_name FROM users WHERE user_id = $1',
      [studentId]
    );
    
    const lastDutyResult = await query(
      'SELECT MAX(date) as last_duty_date FROM attendance WHERE student_id = $1',
      [studentId]
    );
    
    const stats = result.rows[0].statistics;
    const studentName = studentResult.rows[0]?.full_name || 'N/A';
    const lastDutyDate = lastDutyResult.rows[0]?.last_duty_date || null;
    
    res.json({ 
      total_hours_completed: parseFloat(stats.summary?.total_hours || 0),
      total_days_present: parseInt(stats.summary?.total_days || 0),
      last_duty_date: lastDutyDate ? lastDutyDate.toISOString().split('T')[0] : null,
      avg_hours_per_day: parseFloat(stats.summary?.avg_hours_per_day || 0),
      student_name: studentName
    });
  } catch (error) {
    console.error('Get summary error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Verify attendance
router.put('/verify/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const result = await query(
      `UPDATE attendance 
       SET verified = true 
       WHERE attendance_id = $1
       RETURNING *`,
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Attendance record not found' });
    }

    res.json({
      message: 'Attendance verified successfully',
      attendance: result.rows[0]
    });
  } catch (error) {
    console.error('Verify attendance error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;

