const express = require('express');
const router = express.Router();
const { query } = require('../../config/db');
const jwt = require('jsonwebtoken');

// Authentication middleware
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  jwt.verify(token, process.env.JWT_SECRET || 'your_secret_key', (err, user) => {
    if (err) {
      return res.status(403).json({ error: 'Invalid or expired token' });
    }
    req.user = user;
    next();
  });
};

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

    if (generated_by) {
      sql += ` AND r.generated_by = $${paramCount}`;
      params.push(generated_by);
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
    const { report_type, content, report_period_start, report_period_end } = req.body;
    const generated_by = req.user.user_id;

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
      
      res.status(201).json({
        message: 'Report created successfully',
        report: reportResult.rows[0].report
      });
    } else {
      res.status(400).json({
        error: 'Failed to create report',
        errors: response.errors || []
      });
    }
  } catch (error) {
    console.error('Create report error:', error);
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

module.exports = router;

