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

// Create report - Using stored procedure
router.post('/', async (req, res) => {
  try {
    const { report_type, generated_by, content, report_period_start, report_period_end } = req.body;

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
router.get('/:id', async (req, res) => {
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

// Create OJT record - Using stored procedure
router.post('/ojt/records', async (req, res) => {
  try {
    const { 
      student_id, company_name, coordinator_id, supervisor_id, 
      start_date, end_date, required_hours, company_address, company_contact 
    } = req.body;

    const result = await query(
      'SELECT create_ojt_record($1, $2, $3, $4, $5, $6, $7, $8, $9) as result',
      [
        student_id, company_name, coordinator_id, supervisor_id,
        start_date, end_date || null, required_hours || 300,
        company_address || null, company_contact || null
      ]
    );

    const response = result.rows[0].result;

    if (response.success) {
      // Get the created OJT record
      const recordResult = await query(
        'SELECT get_ojt_record($1) as record',
        [response.record_id]
      );
      
      res.status(201).json({
        message: 'OJT record created successfully',
        record: recordResult.rows[0].record
      });
    } else {
      res.status(400).json({
        error: 'Validation failed',
        errors: response.errors
      });
    }
  } catch (error) {
    console.error('Create OJT record error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;

