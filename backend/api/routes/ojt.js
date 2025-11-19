const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const { query } = require('../../config/db');

// Middleware to verify JWT token
const authenticateToken = (req, res, next) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    
    if (!token) {
      return res.status(401).json({ error: 'No token provided' });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your_secret_key');
    req.user = decoded;
    next();
  } catch (error) {
    return res.status(401).json({ error: 'Invalid token' });
  }
};

// Get OJT records - Requires authentication
router.get('/records', authenticateToken, async (req, res) => {
  try {
    console.log('GET /api/ojt/records - Request received', {
      query: req.query,
      user: req.user
    });
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

// Get OJT record by ID - Requires authentication
router.get('/records/:recordId', authenticateToken, async (req, res) => {
  try {
    const { recordId } = req.params;
    
    const result = await query(
      'SELECT get_ojt_record($1) as record',
      [recordId]
    );

    if (result.rows[0].record) {
      res.json({ record: result.rows[0].record });
    } else {
      res.status(404).json({ error: 'OJT record not found' });
    }
  } catch (error) {
    console.error('Get OJT record error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create OJT record - Using stored procedure - Requires authentication
router.post('/records', authenticateToken, async (req, res) => {
  try {
    const { 
      student_id, company_name, coordinator_id, supervisor_id, 
      start_date, end_date, required_hours, company_address, company_contact 
    } = req.body;

    if (!student_id || !coordinator_id || !supervisor_id) {
      return res.status(400).json({ 
        error: 'student_id, coordinator_id, and supervisor_id are required' 
      });
    }

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

// Update OJT record - Using stored procedure - Requires authentication
router.put('/records/:recordId', authenticateToken, async (req, res) => {
  try {
    const { recordId } = req.params;
    const { 
      company_name, start_date, end_date, required_hours, 
      status, company_address, company_contact 
    } = req.body;

    const result = await query(
      'SELECT update_ojt_record($1, $2, $3, $4, $5, $6, $7, $8) as result',
      [
        recordId, company_name, start_date, end_date,
        required_hours, status, company_address, company_contact
      ]
    );

    const response = result.rows[0].result;

    if (response.success) {
      const recordResult = await query(
        'SELECT get_ojt_record($1) as record',
        [recordId]
      );
      
      res.json({
        message: 'OJT record updated successfully',
        record: recordResult.rows[0].record
      });
    } else {
      res.status(400).json({
        error: 'Validation failed',
        errors: response.errors
      });
    }
  } catch (error) {
    console.error('Update OJT record error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Delete OJT record - Requires authentication
router.delete('/records/:recordId', authenticateToken, async (req, res) => {
  try {
    const { recordId } = req.params;
    
    const result = await query(
      'SELECT delete_ojt_record($1) as result',
      [recordId]
    );

    const response = result.rows[0].result;

    if (response.success) {
      res.json({ message: 'OJT record deleted successfully' });
    } else {
      res.status(400).json({
        error: 'Failed to delete OJT record',
        errors: response.errors
      });
    }
  } catch (error) {
    console.error('Delete OJT record error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Test endpoint to verify route is working (no auth required for testing)
router.get('/test', (req, res) => {
  res.json({ message: 'OJT routes are working!', path: req.path, originalUrl: req.originalUrl });
});

module.exports = router;

