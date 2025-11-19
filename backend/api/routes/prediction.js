const express = require('express');
const router = express.Router();
const axios = require('axios');
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

// Get performance predictions (using stored procedure)
router.get('/performance', async (req, res) => {
  try {
    const { student_id } = req.query;

    if (!student_id) {
      return res.status(400).json({ error: 'student_id is required' });
    }

    // Use stored procedure for real-time prediction generation
    const result = await query(
      'SELECT generate_performance_prediction($1) as prediction',
      [student_id]
    );

    res.json({ 
      performance: result.rows[0].prediction,
      generated_at: new Date().toISOString()
    });
  } catch (error) {
    console.error('Get performance error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Generate and save performance prediction
router.post('/performance/generate', async (req, res) => {
  try {
    const { student_id } = req.body;

    if (!student_id) {
      return res.status(400).json({ error: 'student_id is required' });
    }

    // Generate prediction using stored procedure
    const predictionResult = await query(
      'SELECT generate_performance_prediction($1) as prediction',
      [student_id]
    );

    const prediction = predictionResult.rows[0].prediction;

    // Save to ai_insights table
    const insertResult = await query(
      `INSERT INTO ai_insights (student_id, model_name, insight_type, result, confidence, input_data)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [
        student_id,
        'Performance Prediction Model',
        'performance_prediction',
        prediction,
        prediction.confidence,
        JSON.stringify({ generated_via: 'api', generated_at: new Date().toISOString() })
      ]
    );

    res.status(201).json({
      message: 'Performance prediction generated and saved successfully',
      prediction: prediction,
      insight: insertResult.rows[0]
    });
  } catch (error) {
    console.error('Generate performance error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get risk assessment for student
router.get('/risk-assessment/:student_id', async (req, res) => {
  try {
    const { student_id } = req.params;

    const result = await query(
      'SELECT * FROM calculate_risk_score($1)',
      [student_id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Student not found or no OJT record' });
    }

    res.json({ 
      risk_assessment: result.rows[0],
      assessed_at: new Date().toISOString()
    });
  } catch (error) {
    console.error('Get risk assessment error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get at-risk students
router.get('/at-risk', async (req, res) => {
  try {
    const { level } = req.query; // 'High', 'Medium', or undefined for all

    const result = await query(
      'SELECT * FROM get_at_risk_students($1)',
      [level || null]
    );

    res.json({ 
      at_risk_students: result.rows,
      count: result.rows.length,
      risk_level_filter: level || 'All'
    });
  } catch (error) {
    console.error('Get at-risk students error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Generate batch predictions for all active students
router.post('/batch', async (req, res) => {
  try {
    const result = await query('SELECT * FROM generate_batch_predictions()');

    res.json({
      message: `Generated ${result.rows.length} predictions successfully`,
      predictions: result.rows,
      generated_at: new Date().toISOString()
    });
  } catch (error) {
    console.error('Batch prediction error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Daily risk prediction for a student
router.get('/daily/:studentId', async (req, res) => {
  const studentId = req.params.studentId;

  try {
    // 1) Build DAILY snapshot from DB
    //    Use today's date (CURRENT_DATE) for attendance today,
    //    and cumulative data for to-date values.

    const snapshotResult = await query(`
      WITH coordinator_evals AS (
        SELECT COALESCE(AVG(e.total_score), 0) AS avg_score
        FROM evaluations e
        JOIN users u ON e.supervisor_id = u.user_id
        WHERE e.student_id = $1 AND u.role = 'Coordinator'
      ),
      partner_evals AS (
        SELECT COALESCE(AVG(e.total_score), 0) AS avg_score
        FROM evaluations e
        JOIN users u ON e.supervisor_id = u.user_id
        WHERE e.student_id = $1 AND u.role = 'Supervisor'
      ),
      narrative_evals AS (
        SELECT COALESCE(AVG(e.total_score), 0) AS avg_score
        FROM evaluations e
        WHERE e.student_id = $1
      ),
      attendance_stats AS (
        SELECT 
          COALESCE(COUNT(DISTINCT a.date), 0) AS days_present,
          COALESCE(SUM(a.total_hours), 0) AS total_hours_completed,
          COALESCE(SUM(CASE WHEN a.date = CURRENT_DATE THEN a.total_hours ELSE 0 END), 0) AS attendance_today_hours
        FROM attendance a
        WHERE a.student_id = $1
      )
      SELECT 
        (SELECT avg_score FROM coordinator_evals) AS coord_eval_score,
        (SELECT avg_score FROM narrative_evals) AS narrative_score,
        (SELECT avg_score FROM partner_evals) AS partner_eval_score,
        (SELECT days_present FROM attendance_stats) AS days_present,
        (SELECT total_hours_completed FROM attendance_stats) AS total_hours_completed,
        (SELECT attendance_today_hours FROM attendance_stats) AS attendance_today_hours
    `, [studentId]);

    if (!snapshotResult.rows || snapshotResult.rows.length === 0) {
      return res.status(404).json({ error: 'No data for this student' });
    }

    const snap = snapshotResult.rows[0];

    // Use coordinator eval as daily progress if available, otherwise use narrative
    const dailyProgressScore = parseFloat(snap.coord_eval_score) || parseFloat(snap.narrative_score) || 0;

    const payload = {
      daily_progress_score: dailyProgressScore,
      narrative_score: parseFloat(snap.narrative_score) || 0,
      coord_eval_score: parseFloat(snap.coord_eval_score) || 0,
      partner_eval_score: parseFloat(snap.partner_eval_score) || 0,
      attendance_days_present: parseFloat(snap.days_present) || 0,
      attendance_today_hours: parseFloat(snap.attendance_today_hours) || 0,
      total_hours_completed: parseFloat(snap.total_hours_completed) || 0
    };

    // 2) Call Python Flask AI
    // Replace with your Flask server URL (use environment variable in production)
    const flaskUrl = process.env.FLASK_AI_URL || 'http://localhost:5000';
    
    let aiRes;
    try {
      aiRes = await axios.post(`${flaskUrl}/predict`, payload, {
        timeout: 10000, // 10 second timeout
        headers: {
          'Content-Type': 'application/json'
        }
      });
    } catch (axiosError) {
      console.error('Flask AI service error:', axiosError.message);
      if (axiosError.code === 'ECONNREFUSED' || axiosError.code === 'ETIMEDOUT') {
        return res.status(503).json({ 
          error: 'AI prediction service unavailable',
          message: 'Cannot connect to Flask AI service. Please ensure it is running.',
          snapshot: payload
        });
      }
      throw axiosError;
    }

    const prediction = aiRes.data;

    // 3) Optional: insert into ai_insights table
    try {
      await query(
        `INSERT INTO ai_insights (student_id, model_name, insight_type, result, confidence, input_data)
         VALUES ($1, $2, $3, $4, $5, $6)
         RETURNING insight_id`,
        [
          studentId,
          'Daily Risk Prediction Ensemble',
          'daily_risk_prediction',
          JSON.stringify(prediction.prediction),
          prediction.prediction.probability || 0,
          JSON.stringify(payload)
        ]
      );
    } catch (insertError) {
      // Log but don't fail the request if insert fails
      console.warn('Failed to save prediction to ai_insights:', insertError.message);
    }

    return res.json({
      student_id: parseInt(studentId),
      snapshot: payload,
      ai_prediction: prediction,
      generated_at: new Date().toISOString()
    });
  } catch (err) {
    console.error('Daily prediction error:', err);
    
    // Log critical errors to database
    try {
      await query(
        `INSERT INTO api_error_logs (route, method, status_code, error_message)
         VALUES ($1, $2, $3, $4)`,
        ['/api/prediction/daily/:studentId', 'GET', 500, err.message || 'Unknown error']
      );
    } catch (logError) {
      console.error('Failed to log error to database:', logError);
    }
    
    return res.status(500).json({ 
      error: 'Internal server error',
      message: err.message 
    });
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

    // Validation
    if (!user_id || !query || !response) {
      return res.status(400).json({ 
        error: 'Missing required fields: user_id, query, and response are required' 
      });
    }

    const result = await query(
      `INSERT INTO chatbot_logs (user_id, query, response, model_used)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [user_id, query, response, model_used || 'rule-based']
    );

    res.status(201).json({
      message: 'Chatbot log saved successfully',
      log: result.rows[0]
    });
  } catch (error) {
    console.error('Save chatbot log error:', error);
    
    // Log critical errors to database
    try {
      await query(
        `INSERT INTO api_error_logs (route, method, status_code, error_message)
         VALUES ($1, $2, $3, $4)`,
        ['/api/prediction/chatbot/logs', 'POST', 500, error.message || 'Unknown error']
      );
    } catch (logError) {
      console.error('Failed to log error to database:', logError);
    }
    
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get chatbot logs for a specific user
router.get('/chatbot/logs/:userId', async (req, res) => {
  try {
    const userId = req.params.userId;

    const result = await query(
      `SELECT chat_id, user_id, query, response, model_used, timestamp
       FROM chatbot_logs
       WHERE user_id = $1
       ORDER BY timestamp DESC
       LIMIT 100`,
      [userId]
    );

    res.json({ logs: result.rows });
  } catch (error) {
    console.error('Get chatbot logs error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;

