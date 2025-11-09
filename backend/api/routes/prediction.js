const express = require('express');
const router = express.Router();
const { query } = require('../../config/db');

// Get AI insights
router.get('/insights', async (req, res) => {
  try {
    const { student_id } = req.query;
    
    let sql = `
      SELECT a.*, u.full_name AS student_name
      FROM ai_insights a
      JOIN users u ON a.student_id = u.user_id
      WHERE 1=1
    `;
    const params = [];

    if (student_id) {
      sql += ' AND a.student_id = $1';
      params.push(student_id);
    }

    sql += ' ORDER BY a.created_at DESC';

    const result = await query(sql, params);
    res.json({ insights: result.rows });
  } catch (error) {
    console.error('Get insights error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create AI insight
router.post('/insights', async (req, res) => {
  try {
    const { student_id, model_name, insight_type, result, confidence } = req.body;

    const insertResult = await query(
      `INSERT INTO ai_insights (student_id, model_name, insight_type, result, confidence)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [student_id, model_name, insight_type, JSON.stringify(result), confidence]
    );

    res.status(201).json({
      message: 'AI insight created successfully',
      insight: insertResult.rows[0]
    });
  } catch (error) {
    console.error('Create insight error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get performance predictions
router.get('/performance', async (req, res) => {
  try {
    const { student_id } = req.query;

    const result = await query(
      `SELECT 
        u.full_name,
        e.total_score,
        a.insight_type,
        a.result->>'predicted_performance' AS prediction,
        a.confidence,
        a.created_at
       FROM users u
       JOIN evaluations e ON u.user_id = e.student_id
       JOIN ai_insights a ON u.user_id = a.student_id
       WHERE u.user_id = $1
       ORDER BY a.created_at DESC
       LIMIT 1`,
      student_id ? [student_id] : []
    );

    res.json({ performance: result.rows });
  } catch (error) {
    console.error('Get performance error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Chatbot logs
router.get('/chatbot/logs', async (req, res) => {
  try {
    const { user_id } = req.query;
    
    let sql = `
      SELECT c.*, u.full_name
      FROM chatbot_logs c
      JOIN users u ON c.user_id = u.user_id
      WHERE 1=1
    `;
    const params = [];

    if (user_id) {
      sql += ' AND c.user_id = $1';
      params.push(user_id);
    }

    sql += ' ORDER BY c.timestamp DESC LIMIT 100';

    const result = await query(sql, params);
    res.json({ logs: result.rows });
  } catch (error) {
    console.error('Get chatbot logs error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Save chatbot log
router.post('/chatbot/logs', async (req, res) => {
  try {
    const { user_id, query, response, model_used } = req.body;

    const result = await query(
      `INSERT INTO chatbot_logs (user_id, query, response, model_used)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [user_id, query, response, model_used]
    );

    res.status(201).json({
      message: 'Chatbot log saved successfully',
      log: result.rows[0]
    });
  } catch (error) {
    console.error('Save chatbot log error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;

