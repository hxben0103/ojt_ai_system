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

// Create evaluation
router.post('/', async (req, res) => {
  try {
    const { student_id, supervisor_id, criteria, total_score, feedback } = req.body;

    const result = await query(
      `INSERT INTO evaluations (student_id, supervisor_id, criteria, total_score, feedback)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [student_id, supervisor_id, JSON.stringify(criteria), total_score, feedback]
    );

    res.status(201).json({
      message: 'Evaluation created successfully',
      evaluation: result.rows[0]
    });
  } catch (error) {
    console.error('Create evaluation error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update evaluation
router.put('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { criteria, total_score, feedback } = req.body;

    const result = await query(
      `UPDATE evaluations 
       SET criteria = $1, total_score = $2, feedback = $3
       WHERE eval_id = $4
       RETURNING *`,
      [JSON.stringify(criteria), total_score, feedback, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Evaluation not found' });
    }

    res.json({
      message: 'Evaluation updated successfully',
      evaluation: result.rows[0]
    });
  } catch (error) {
    console.error('Update evaluation error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get evaluation by ID
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;

    const result = await query(
      `SELECT e.*, 
              u1.full_name AS student_name,
              u2.full_name AS supervisor_name
       FROM evaluations e
       JOIN users u1 ON e.student_id = u1.user_id
       JOIN users u2 ON e.supervisor_id = u2.user_id
       WHERE e.eval_id = $1`,
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Evaluation not found' });
    }

    res.json({ evaluation: result.rows[0] });
  } catch (error) {
    console.error('Get evaluation error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;

