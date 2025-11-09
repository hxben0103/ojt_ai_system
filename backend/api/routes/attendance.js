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

// Create attendance record (Time In)
router.post('/time-in', async (req, res) => {
  try {
    const { student_id, date, time_in } = req.body;

    const result = await query(
      `INSERT INTO attendance (student_id, date, time_in)
       VALUES ($1, $2, $3)
       RETURNING *`,
      [student_id, date || new Date().toISOString().split('T')[0], time_in || new Date().toTimeString().split(' ')[0]]
    );

    res.status(201).json({
      message: 'Time in recorded successfully',
      attendance: result.rows[0]
    });
  } catch (error) {
    console.error('Time in error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update attendance record (Time Out)
router.put('/time-out', async (req, res) => {
  try {
    const { attendance_id, time_out } = req.body;

    // Get existing record
    const existing = await query(
      'SELECT * FROM attendance WHERE attendance_id = $1',
      [attendance_id]
    );

    if (existing.rows.length === 0) {
      return res.status(404).json({ error: 'Attendance record not found' });
    }

    const attendance = existing.rows[0];
    const timeIn = new Date(`2000-01-01 ${attendance.time_in}`);
    const timeOut = new Date(`2000-01-01 ${time_out}`);
    const diffMs = timeOut - timeIn;
    const totalHours = (diffMs / (1000 * 60 * 60)).toFixed(2);

    const result = await query(
      `UPDATE attendance 
       SET time_out = $1, total_hours = $2
       WHERE attendance_id = $3
       RETURNING *`,
      [time_out, totalHours, attendance_id]
    );

    res.json({
      message: 'Time out recorded successfully',
      attendance: result.rows[0]
    });
  } catch (error) {
    console.error('Time out error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get attendance summary
router.get('/summary', async (req, res) => {
  try {
    const { student_id } = req.query;

    let sql = `
      SELECT 
        u.full_name,
        COUNT(a.date) AS total_days,
        SUM(a.total_hours) AS total_hours,
        AVG(a.total_hours) AS avg_hours_per_day
      FROM attendance a
      JOIN users u ON a.student_id = u.user_id
      WHERE 1=1
    `;
    const params = [];

    if (student_id) {
      sql += ' AND a.student_id = $1';
      params.push(student_id);
      sql += ' GROUP BY u.full_name';
    } else {
      sql += ' GROUP BY u.full_name';
    }

    const result = await query(sql, params);
    res.json({ summary: result.rows });
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

