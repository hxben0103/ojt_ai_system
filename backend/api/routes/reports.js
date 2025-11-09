const express = require('express');
const router = express.Router();
const { query } = require('../../config/db');

// Get all reports
router.get('/', async (req, res) => {
  try {
    const { report_type, generated_by } = req.query;
    
    let sql = `
      SELECT r.*, u.full_name AS generated_by_name
      FROM system_reports r
      JOIN users u ON r.generated_by = u.user_id
      WHERE 1=1
    `;
    const params = [];
    let paramCount = 1;

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

// Create report
router.post('/', async (req, res) => {
  try {
    const { report_type, generated_by, content } = req.body;

    const result = await query(
      `INSERT INTO system_reports (report_type, generated_by, content)
       VALUES ($1, $2, $3)
       RETURNING *`,
      [report_type, generated_by, JSON.stringify(content)]
    );

    res.status(201).json({
      message: 'Report created successfully',
      report: result.rows[0]
    });
  } catch (error) {
    console.error('Create report error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get report by ID
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const result = await query(
      `SELECT r.*, u.full_name AS generated_by_name
       FROM system_reports r
       JOIN users u ON r.generated_by = u.user_id
       WHERE r.report_id = $1`,
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Report not found' });
    }

    res.json({ report: result.rows[0] });
  } catch (error) {
    console.error('Get report error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get OJT records
router.get('/ojt/records', async (req, res) => {
  try {
    const { student_id, coordinator_id, supervisor_id, status } = req.query;
    
    let sql = `
      SELECT o.*,
             s.full_name AS student_name,
             c.full_name AS coordinator_name,
             sup.full_name AS supervisor_name
      FROM ojt_records o
      JOIN users s ON o.student_id = s.user_id
      JOIN users c ON o.coordinator_id = c.user_id
      JOIN users sup ON o.supervisor_id = sup.user_id
      WHERE 1=1
    `;
    const params = [];
    let paramCount = 1;

    if (student_id) {
      sql += ` AND o.student_id = $${paramCount}`;
      params.push(student_id);
      paramCount++;
    }

    if (coordinator_id) {
      sql += ` AND o.coordinator_id = $${paramCount}`;
      params.push(coordinator_id);
      paramCount++;
    }

    if (supervisor_id) {
      sql += ` AND o.supervisor_id = $${paramCount}`;
      params.push(supervisor_id);
      paramCount++;
    }

    if (status) {
      sql += ` AND o.status = $${paramCount}`;
      params.push(status);
      paramCount++;
    }

    sql += ' ORDER BY o.start_date DESC';

    const result = await query(sql, params);
    res.json({ records: result.rows });
  } catch (error) {
    console.error('Get OJT records error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create OJT record
router.post('/ojt/records', async (req, res) => {
  try {
    const { student_id, company_name, coordinator_id, supervisor_id, start_date, end_date, status } = req.body;

    const result = await query(
      `INSERT INTO ojt_records (student_id, company_name, coordinator_id, supervisor_id, start_date, end_date, status)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING *`,
      [student_id, company_name, coordinator_id, supervisor_id, start_date, end_date, status || 'Ongoing']
    );

    res.status(201).json({
      message: 'OJT record created successfully',
      record: result.rows[0]
    });
  } catch (error) {
    console.error('Create OJT record error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;

