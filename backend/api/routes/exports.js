const express = require('express');
const router = express.Router();
const { query } = require('../../config/db');
const authenticateToken = require('../middleware/auth');

// Helper: Convert rows to CSV string
function toCSV(rows, columns) {
  if (!rows || rows.length === 0) return columns.join(',') + '\n';
  
  const header = columns.join(',');
  const body = rows.map(row => 
    columns.map(col => {
      let val = row[col];
      if (val === null || val === undefined) val = '';
      val = String(val).replace(/"/g, '""'); // Escape quotes
      if (val.includes(',') || val.includes('"') || val.includes('\n')) {
        val = `"${val}"`;
      }
      return val;
    }).join(',')
  ).join('\n');
  
  return header + '\n' + body + '\n';
}

// Export Attendance Records (CSV)
router.get('/attendance', authenticateToken, async (req, res) => {
  try {
    const { role, user_id } = req.user;
    const { start, end } = req.query;
    
    let sql = `
      SELECT 
        u.full_name AS student_name,
        u.student_id AS school_id,
        u.course,
        a.date,
        a.morning_in, a.morning_out, a.afternoon_in, a.afternoon_out,
        a.total_hours, a.regular_hours, a.overtime_hours,
        a.status AS attendance_status,
        a.verification_status,
        a.trust_score
      FROM attendance a
      JOIN users u ON a.student_id = u.user_id
    `;
    
    const params = [];
    let paramCount = 1;
    
    // Coordinator: only their students
    if (role === 'Coordinator') {
      sql += ` JOIN ojt_records o ON a.student_id = o.student_id AND o.coordinator_id = $${paramCount}`;
      params.push(user_id);
      paramCount++;
    }
    
    sql += ` WHERE 1=1`;
    
    if (start) {
      sql += ` AND a.date >= $${paramCount}`;
      params.push(start);
      paramCount++;
    }
    if (end) {
      sql += ` AND a.date <= $${paramCount}`;
      params.push(end);
      paramCount++;
    }
    
    sql += ` ORDER BY a.date DESC, u.full_name`;
    
    const result = await query(sql, params);
    
    const csv = toCSV(result.rows, [
      'student_name', 'school_id', 'course', 'date',
      'morning_in', 'morning_out', 'afternoon_in', 'afternoon_out',
      'total_hours', 'regular_hours', 'overtime_hours',
      'attendance_status', 'verification_status', 'trust_score'
    ]);
    
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename="attendance_export.csv"');
    res.send(csv);
  } catch (error) {
    console.error('Export attendance error:', error);
    res.status(500).json({ error: 'Failed to export attendance data' });
  }
});

// Export Student List (CSV)
router.get('/students', authenticateToken, async (req, res) => {
  try {
    const { role, user_id } = req.user;
    
    let sql = `
      SELECT 
        u.full_name AS student_name,
        u.student_id AS school_id,
        u.email,
        u.course,
        u.program,
        u.gender,
        u.contact_number,
        u.status,
        o.company_name,
        o.status AS ojt_status,
        o.start_date,
        o.end_date,
        o.required_hours,
        COALESCE(p.completion_percentage, 0) AS progress_percent
      FROM users u
      LEFT JOIN ojt_records o ON u.user_id = o.student_id
      LEFT JOIN LATERAL (
        SELECT completion_percentage FROM get_student_progress(u.user_id) LIMIT 1
      ) p ON true
      WHERE u.role = 'Student'
    `;
    
    const params = [];
    
    if (role === 'Coordinator') {
      sql += ` AND o.coordinator_id = $1`;
      params.push(user_id);
    }
    
    sql += ` ORDER BY u.full_name`;
    
    const result = await query(sql, params);
    
    const csv = toCSV(result.rows, [
      'student_name', 'school_id', 'email', 'course', 'program', 'gender',
      'contact_number', 'status', 'company_name', 'ojt_status',
      'start_date', 'end_date', 'required_hours', 'progress_percent'
    ]);
    
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename="students_export.csv"');
    res.send(csv);
  } catch (error) {
    console.error('Export students error:', error);
    res.status(500).json({ error: 'Failed to export student data' });
  }
});

// Export Performance Summary (CSV)
router.get('/performance', authenticateToken, async (req, res) => {
  try {
    const { role, user_id } = req.user;
    
    let sql = `
      SELECT DISTINCT ON (u.user_id)
        u.full_name AS student_name,
        u.student_id AS school_id,
        u.course,
        o.company_name,
        ai.result->>'predicted_performance' AS ai_performance_score,
        ai.result->>'risk_level' AS risk_level,
        ai.result->>'grade_equivalent' AS grade_equivalent,
        ai.confidence,
        COALESCE(p.completion_percentage, 0) AS progress_percent,
        ai.created_at AS prediction_date
      FROM users u
      JOIN ojt_records o ON u.user_id = o.student_id AND o.status IN ('Ongoing', 'Active')
      LEFT JOIN ai_insights ai ON u.user_id = ai.student_id AND ai.insight_type = 'performance_prediction'
      LEFT JOIN LATERAL (
        SELECT completion_percentage FROM get_student_progress(u.user_id) LIMIT 1
      ) p ON true
      WHERE u.role = 'Student'
    `;
    
    const params = [];
    
    if (role === 'Coordinator') {
      sql += ` AND o.coordinator_id = $1`;
      params.push(user_id);
    }
    
    sql += ` ORDER BY u.user_id, ai.created_at DESC`;
    
    const result = await query(sql, params);
    
    const csv = toCSV(result.rows, [
      'student_name', 'school_id', 'course', 'company_name',
      'ai_performance_score', 'risk_level', 'grade_equivalent',
      'confidence', 'progress_percent', 'prediction_date'
    ]);
    
    res.setHeader('Content-Type', 'text/csv');
    res.setHeader('Content-Disposition', 'attachment; filename="performance_export.csv"');
    res.send(csv);
  } catch (error) {
    console.error('Export performance error:', error);
    res.status(500).json({ error: 'Failed to export performance data' });
  }
});

module.exports = router;
