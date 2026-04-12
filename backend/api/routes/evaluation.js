const express = require('express');
const router = express.Router();
const { query } = require('../../config/db');
const jwt = require('jsonwebtoken');

// ✅ Security: Enforce JWT_SECRET from environment — never use a fallback
const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET) {
  console.error('❌ FATAL: JWT_SECRET environment variable is not set. Please configure your .env file.');
  process.exit(1);
}

// Authentication middleware
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ error: 'Invalid or expired token' });
    }
    req.user = user;
    next();
  });
};

// Get all evaluations
router.get('/', authenticateToken, async (req, res) => {
  try {
    const { student_id, supervisor_id } = req.query;
    const { role, user_id } = req.user;
    
    let sql = `
      SELECT e.*, 
             u1.full_name AS student_name,
             u2.full_name AS supervisor_name
      FROM evaluations e
      JOIN users u1 ON e.student_id = u1.user_id
      JOIN users u2 ON e.supervisor_id = u2.user_id
      -- Join OJT records for coordinator filtering
      LEFT JOIN ojt_records o ON e.student_id = o.student_id AND o.status IN ('Ongoing', 'Active')
      WHERE 1=1
    `;
    const params = [];
    let paramCount = 1;

    // Data Isolation: Coordinators only see their students
    if (role === 'Coordinator') {
      sql += ` AND o.coordinator_id = $${paramCount}`;
      params.push(user_id);
      paramCount++;
    }
    if (student_id) {
      sql += ` AND e.student_id = $${paramCount}`;
      params.push(student_id);
      paramCount++;
    }

    if (supervisor_id) {
      sql += ` AND e.supervisor_id = $${paramCount}`;
      params.push(supervisor_id);
      paramCount++;
    }

    sql += ' ORDER BY e.date_evaluated DESC';

    const result = await query(sql, params);
    res.json({ evaluations: result.rows });
  } catch (error) {
    console.error('Get evaluations error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create evaluation - Using stored procedure
router.post('/', authenticateToken, async (req, res) => {
  try {
    const { 
      student_id, supervisor_id, criteria, total_score, feedback,
      evaluation_period_start, evaluation_period_end 
    } = req.body;

    const result = await query(
      'SELECT create_evaluation($1, $2, $3, $4, $5, $6, $7) as result',
      [
        student_id, supervisor_id, JSON.stringify(criteria), total_score, feedback,
        evaluation_period_start || null, evaluation_period_end || null
      ]
    );

    const response = result.rows[0].result;

    if (response.success) {
      // Get the created evaluation
      const evalResult = await query(
        'SELECT get_evaluation($1) as evaluation',
        [response.eval_id]
      );
      
      res.status(201).json({
        message: 'Evaluation created successfully',
        evaluation: evalResult.rows[0].evaluation
      });
    } else {
      res.status(400).json({
        error: 'Validation failed',
        errors: response.errors
      });
    }
  } catch (error) {
    console.error('Create evaluation error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update evaluation - Using stored procedure
router.put('/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { criteria, total_score, feedback, status } = req.body;

    const result = await query(
      'SELECT update_evaluation($1, $2, $3, $4, $5) as result',
      [
        id,
        criteria ? JSON.stringify(criteria) : null,
        total_score || null,
        feedback || null,
        status || null
      ]
    );

    const response = result.rows[0].result;

    if (response.success) {
      // Get the updated evaluation
      const evalResult = await query(
        'SELECT get_evaluation($1) as evaluation',
        [id]
      );
      
      res.json({
        message: 'Evaluation updated successfully',
        evaluation: evalResult.rows[0].evaluation
      });
    } else {
      res.status(400).json({
        error: response.error || 'Evaluation not found',
        errors: response.errors || []
      });
    }
  } catch (error) {
    console.error('Update evaluation error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get evaluation by ID - Using stored procedure
router.get('/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { role, user_id } = req.user;

    // Data Isolation: For coordinators, verify the student in this evaluation belongs to them
    if (role === 'Coordinator') {
       const accessCheck = await query(
         `SELECT e.eval_id 
          FROM evaluations e
          JOIN ojt_records o ON e.student_id = o.student_id
          WHERE e.eval_id = $1 AND o.coordinator_id = $2 AND o.status IN ('Ongoing', 'Active')`,
         [id, user_id]
       );
       if (accessCheck.rows.length === 0) {
         return res.status(403).json({ error: 'Access Denied', message: 'You can only view evaluations for students assigned to you.' });
       }
    }

    const result = await query('SELECT get_evaluation($1) as evaluation', [id]);
    const evaluation = result.rows[0].evaluation;

    if (evaluation.error) {
      return res.status(404).json(evaluation);
    }

    res.json({ evaluation });
  } catch (error) {
    console.error('Get evaluation error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;

