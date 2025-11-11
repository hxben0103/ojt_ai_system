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

// Create attendance record (Time In) - Using stored procedure
router.post('/time-in', async (req, res) => {
  try {
    const { student_id, date, time_in } = req.body;

    const currentDate = date || new Date().toISOString().split('T')[0];
    const currentTime = time_in || new Date().toTimeString().split(' ')[0];

    const result = await query(
      'SELECT create_attendance($1, $2, $3, NULL, NULL, NULL, NULL, NULL) as result',
      [student_id, currentDate, currentTime]
    );

    const response = result.rows[0].result;

    if (response.success) {
      // Get the created attendance record
      const attendanceResult = await query(
        'SELECT get_attendance($1) as attendance',
        [response.attendance_id]
      );
      
      res.status(201).json({
        message: 'Time in recorded successfully',
        attendance: attendanceResult.rows[0].attendance
      });
    } else {
      res.status(400).json({
        error: 'Validation failed',
        errors: response.errors
      });
    }
  } catch (error) {
    console.error('Time in error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update attendance record (Time Out) - Using stored procedure
router.put('/time-out', async (req, res) => {
  try {
    const { attendance_id, time_out } = req.body;

    if (!attendance_id || !time_out) {
      return res.status(400).json({ error: 'attendance_id and time_out are required' });
    }

    const result = await query(
      'SELECT update_attendance($1, NULL, $2, NULL, NULL, NULL, NULL) as result',
      [attendance_id, time_out]
    );

    const response = result.rows[0].result;

    if (response.success) {
      // Get the updated attendance record
      const attendanceResult = await query(
        'SELECT get_attendance($1) as attendance',
        [attendance_id]
      );
      
      res.json({
        message: 'Time out recorded successfully',
        attendance: attendanceResult.rows[0].attendance
      });
    } else {
      res.status(404).json({
        error: response.error || 'Attendance record not found'
      });
    }
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
      
      const stats = result.rows[0].statistics;
      const studentName = studentResult.rows[0]?.full_name || 'N/A';
      
      res.json({ 
        summary: [{
          full_name: studentName,
          total_days: parseInt(stats.summary?.total_days || 0),
          total_hours: parseFloat(stats.summary?.total_hours || 0),
          avg_hours_per_day: parseFloat(stats.summary?.avg_hours_per_day || 0)
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

