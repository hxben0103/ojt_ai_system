const express = require('express');
const router = express.Router();
const { query } = require('../../config/db');
const authenticateToken = require('../middleware/auth');

// Get all reports
router.get('/', authenticateToken, async (req, res) => {
  try {
    const { report_type } = req.query;
    const { user_id, role } = req.user;
    
    let sql = `
      SELECT r.*, u.full_name AS generated_by_name
      FROM system_reports r
      JOIN users u ON r.generated_by = u.user_id
      WHERE 1=1
    `;
    const params = [];
    let paramCount = 1;

    // Data Isolation: Users only see reports they generated (unless Admin)
    if (role !== 'Admin') {
      sql += ` AND r.generated_by = $${paramCount}`;
      params.push(user_id);
      paramCount++;
    }
    if (report_type) {
      sql += ` AND r.report_type = $${paramCount}`;
      params.push(report_type);
      paramCount++;
    }

    // Optional: Filter by specific generator if provided in query (e.g. for Admin)
    if (req.query.generated_by) {
      sql += ` AND r.generated_by = $${paramCount}`;
      params.push(req.query.generated_by);
      paramCount++;
    }

    sql += ' ORDER BY r.created_at DESC';

    const result = await query(sql, params);
    res.json({ reports: result.rows });
  } catch (error) {
    console.error('Get reports error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create report - Using stored procedure
router.post('/', authenticateToken, async (req, res) => {
  try {
    let { report_type, content, report_period_start, report_period_end } = req.body;
    const generated_by = req.user.user_id;

    // Special handling for Coordinator Summary: Auto-generate aggregate content
    if (report_type === 'Coordinator Summary' || report_type === 'Admin Master Summary') {
      let querySql = `
        SELECT 
            COALESCE(u.student_id, 'No ID') AS school_id,
            u.full_name AS student_name,
            COALESCE(o.company_name, 'N/A') AS company,
            COALESCE(ai.performance, 'N/A') AS performance,
            COALESCE(p.completion_percentage, 0) AS progress,
            CONCAT(COALESCE(req_stats.completed_count, 0), '/21 Completed') AS compliance_status,
            COALESCE(req_matrix.matrix, '{}') AS requirements_matrix
         FROM users u
         JOIN ojt_records o ON u.user_id = o.student_id
         LEFT JOIN LATERAL (
            SELECT result->>'predicted_performance' AS performance
            FROM ai_insights 
            WHERE student_id = u.user_id 
            ORDER BY created_at DESC LIMIT 1
         ) ai ON true
         LEFT JOIN LATERAL (
            SELECT completion_percentage FROM get_student_progress(u.user_id) LIMIT 1
         ) p ON true
         LEFT JOIN LATERAL (
            SELECT COUNT(*) AS completed_count 
            FROM student_requirements 
            WHERE student_id = u.user_id AND status = 'Completed'
         ) req_stats ON true
         LEFT JOIN LATERAL (
            SELECT json_object_agg(requirement_name, status) AS matrix
            FROM student_requirements
            WHERE student_id = u.user_id
         ) req_matrix ON true
         WHERE o.status IN ('Ongoing', 'Active')
      `;
      
      const queryParams = [];
      if (report_type === 'Coordinator Summary') {
        querySql += ` AND o.coordinator_id = $1`;
        queryParams.push(generated_by);
      }
      
      querySql += ` ORDER BY u.full_name`;
      
      const studentsResult = await query(querySql, queryParams);
      
      content = {
        title: report_type === 'Admin Master Summary' ? 'System-Wide OJT Performance Summary' : 'Class Performance Summary',
        generated_at: new Date().toISOString(),
        student_count: studentsResult.rows.length,
        students: studentsResult.rows,
        summary_stats: {
          total_students: studentsResult.rows.length,
          avg_progress: studentsResult.rows.length > 0
            ? studentsResult.rows.reduce((acc, s) => acc + (parseFloat(s.progress) || 0), 0) / studentsResult.rows.length
            : 0
        }
      };
    }

    const result = await query(
      'SELECT create_system_report($1, $2, $3, $4, $5) as result',
      [
        report_type, generated_by, JSON.stringify(content),
        report_period_start || null, report_period_end || null
      ]
    );

    const response = result.rows[0].result;

    if (response.success) {
      // Get the created report
      const reportResult = await query(
        'SELECT get_system_report($1) as report',
        [response.report_id]
      );
      
      if (!reportResult.rows[0] || !reportResult.rows[0].report) {
        throw new Error('Report created but could not be retrieved');
      }

      res.status(201).json({
        message: 'Report created successfully',
        report: reportResult.rows[0].report
      });
    } else {
      console.warn('Report creation failed in database:', response.errors);
      res.status(400).json({
        error: 'Failed to create report',
        errors: response.errors || []
      });
    }
  } catch (error) {
    console.error('❌ Create report 500 error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get report by ID - Using stored procedure
router.get('/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;

    const result = await query('SELECT get_system_report($1) as report', [id]);
    const report = result.rows[0].report;

    if (report.error) {
      return res.status(404).json(report);
    }

    res.json({ report });
  } catch (error) {
    console.error('Get report error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Delete report
router.delete('/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { user_id, role } = req.user;

    // Check ownership unless Admin
    if (role !== 'Admin') {
      const reportCheck = await query(
        'SELECT generated_by FROM system_reports WHERE report_id = $1',
        [id]
      );
      
      if (reportCheck.rows.length === 0) {
        return res.status(404).json({ error: 'Report not found' });
      }
      
      if (reportCheck.rows[0].generated_by !== user_id) {
        return res.status(403).json({ error: 'You can only delete your own reports' });
      }
    }

    const result = await query('SELECT delete_system_report($1) as result', [id]);
    const response = result.rows[0].result;

    if (response.success) {
      res.json({ message: 'Report deleted successfully' });
    } else {
      res.status(400).json(response);
    }
  } catch (error) {
    console.error('Delete report error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;

