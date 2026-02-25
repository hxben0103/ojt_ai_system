const express = require('express');
const router = express.Router();
const { query } = require('../../config/db');

// Get all evaluations
router.get('/', async (req, res) => {
  try {
    const { student_id, supervisor_id } = req.query;
    
    let sql = `
      SELECT e.*, 
             u1.full_name AS student_name,
             u2.full_name AS supervisor_name
      FROM evaluations e
      JOIN users u1 ON e.student_id = u1.user_id
      JOIN users u2 ON e.supervisor_id = u2.user_id
      WHERE 1=1
    `;
    const params = [];
    let paramCount = 1;

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
router.post('/', async (req, res) => {
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
router.put('/:id', async (req, res) => {
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
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;

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

