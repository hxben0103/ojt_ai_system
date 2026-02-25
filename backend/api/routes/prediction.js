const express = require('express');
const router = express.Router();
const axios = require('axios');
const { query } = require('../../config/db');

/**
 * AI PREDICTION SYSTEM - COMPREHENSIVE MULTI-FEATURE MODEL
 * 
 * This module implements a rich AI prediction system that uses:
 * 
 * 1. ATTENDANCE METRICS (Approved Only)
 *    - Only attendance with status = 'Approved' is counted
 *    - Includes: total hours, attendance rate, late count, absent count
 * 
 * 2. COMPETENCY-BASED DAILY TASKS
 *    - Tracks 11 official OJT competencies
 *    - Only approved tasks contribute to competency hours
 *    - Features: total tasks, task hours, distinct competencies, per-competency hours
 * 
 * 3. OJT GRADING COMPONENTS
 *    - Weekly Progress Report (WPR) - 20%
 *    - Narrative Report (NR) - 20%
 *    - Coordinator Evaluation (CE) - 20%
 *    - Supervisor Evaluation (SE) - 40% (may be missing during active OJT)
 * 
 * 4. CHATBOT ENGAGEMENT
 *    - Total queries and queries in last 30 days
 * 
 * The AI model is trained using these features with proper grading weights.
 * During live prediction, supervisor evaluation may be missing, but the model
 * still provides risk assessment based on available indicators.
 */

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
    // 1) Build COMPREHENSIVE snapshot from DB with all features
    //    Includes: attendance (approved only), competencies, grading components, chatbot engagement

    const snapshotResult = await query(`
      WITH 
      -- Get OJT record for required hours
      ojt_info AS (
        SELECT required_hours, status
        FROM ojt_records
        -- Treat both Ongoing and Active as current OJT records
        WHERE student_id = $1 AND status IN ('Ongoing', 'Active')
        LIMIT 1
      ),
      -- Attendance stats (CRITICAL: Only approved attendance counts)
      attendance_stats AS (
        SELECT 
          COALESCE(SUM(a.total_hours), 0) AS total_hours_completed,
          COALESCE(COUNT(DISTINCT a.date), 0) AS days_present,
          COALESCE(COUNT(CASE WHEN a.time_in > '09:00:00' THEN 1 END), 0) AS late_count,
          COALESCE(MAX(a.date), NULL) AS last_attendance_date
        FROM attendance a
        WHERE a.student_id = $1 AND a.status = 'Approved'
      ),
      -- Competency-based daily tasks (only approved tasks)
      task_stats AS (
        SELECT 
          COUNT(DISTINCT t.task_id) AS total_tasks_logged,
          COALESCE(SUM(t.hours_worked), 0) AS total_task_hours,
          COUNT(DISTINCT tc.competency_id) AS number_of_distinct_competencies
        FROM ojt_daily_tasks t
        LEFT JOIN task_competencies tc ON t.task_id = tc.task_id
        WHERE t.student_id = $1 AND t.status = 'Approved'
      ),
      -- Competency hours breakdown (only approved tasks)
      competency_hours AS (
        SELECT 
          c.competency_id,
          c.title,
          COALESCE(SUM(t.hours_worked), 0) AS hours
        FROM competencies c
        LEFT JOIN task_competencies tc ON c.competency_id = tc.competency_id
        LEFT JOIN ojt_daily_tasks t ON tc.task_id = t.task_id 
          AND t.student_id = $1 
          AND t.status = 'Approved'
        GROUP BY c.competency_id, c.title
      ),
      -- Grading components
      coordinator_eval AS (
        SELECT COALESCE(AVG(e.total_score), 0) AS avg_score
        FROM evaluations e
        JOIN users u ON e.supervisor_id = u.user_id
        WHERE e.student_id = $1 AND u.role = 'Coordinator'
      ),
      supervisor_eval AS (
        SELECT COALESCE(AVG(e.total_score), 0) AS avg_score
        FROM evaluations e
        JOIN users u ON e.supervisor_id = u.user_id
        WHERE e.student_id = $1 AND u.role = 'Supervisor'
      ),
      narrative_eval AS (
        SELECT COALESCE(AVG(e.total_score), 0) AS avg_score
        FROM evaluations e
        WHERE e.student_id = $1
      ),
      -- Chatbot engagement
      chatbot_stats AS (
        SELECT 
          COUNT(*) AS total_queries,
          COUNT(CASE WHEN timestamp >= CURRENT_DATE - INTERVAL '30 days' THEN 1 END) AS queries_last_30_days
        FROM chatbot_logs
        WHERE user_id = $1
      )
      SELECT 
        (SELECT COALESCE(required_hours, 300) FROM ojt_info) AS required_hours,
        (SELECT total_hours_completed FROM attendance_stats) AS total_hours_completed,
        (SELECT days_present FROM attendance_stats) AS days_present,
        (SELECT late_count FROM attendance_stats) AS late_count,
        (SELECT total_tasks_logged FROM task_stats) AS total_tasks_logged,
        (SELECT total_task_hours FROM task_stats) AS total_task_hours,
        (SELECT number_of_distinct_competencies FROM task_stats) AS number_of_distinct_competencies,
        (SELECT avg_score FROM coordinator_eval) AS coordinator_eval_score,
        (SELECT avg_score FROM supervisor_eval) AS supervisor_eval_score,
        (SELECT avg_score FROM narrative_eval) AS narrative_eval_score,
        (SELECT total_queries FROM chatbot_stats) AS total_chatbot_queries,
        (SELECT queries_last_30_days FROM chatbot_stats) AS chatbot_queries_last_30_days,
        -- Competency hours (will be processed separately)
        (SELECT json_agg(json_build_object('title', title, 'hours', hours)) FROM competency_hours) AS competency_hours_json
    `, [studentId]);

    if (!snapshotResult.rows || snapshotResult.rows.length === 0) {
      return res.status(404).json({ error: 'No data for this student' });
    }

    const snap = snapshotResult.rows[0];
    const requiredHours = parseFloat(snap.required_hours) || 300;
    const totalHoursCompleted = parseFloat(snap.total_hours_completed) || 0;
    const daysPresent = parseFloat(snap.days_present) || 0;
    const lateCount = parseInt(snap.late_count) || 0;
    
    // Calculate attendance rate and absent count
    const requiredDays = 25; // Standard OJT period
    const attendanceRate = requiredDays > 0 ? Math.min((daysPresent / requiredDays) * 100, 100) : 0;
    const absentCount = Math.max(0, requiredDays - daysPresent);
    const hoursCompletedRatio = requiredHours > 0 ? totalHoursCompleted / requiredHours : 0;

    // Process competency hours
    const competencyHoursJson = snap.competency_hours_json || [];
    const competencyHoursMap = {};
    competencyHoursJson.forEach(item => {
      const title = item.title || '';
      const hours = parseFloat(item.hours) || 0;
      // Map competency titles to feature names
      const featureName = title.toLowerCase()
        .replace(/\s+/g, '_')
        .replace(/[^a-z0-9_]/g, '');
      competencyHoursMap[featureName] = hours;
    });

    // Get grading components
    // NOTE: WPR (Weekly Progress Report) is NOT stored separately in the DB.
    // Previously this copied narrative_eval_score into WPR, making two features
    // identical. Set to 0 so the model doesn't receive misleading data.
    const weeklyProgressGrade = 0; // No separate WPR column in evaluations table
    const narrativeReportGrade = parseFloat(snap.narrative_eval_score) || 0; // NR
    const coordinatorEvalGrade = parseFloat(snap.coordinator_eval_score) || 0; // CE
    const supervisorEvalGrade = parseFloat(snap.supervisor_eval_score) || 0; // SE (may be 0 during active OJT)

    // Build comprehensive snapshot payload
    const payload = {
      // Attendance features (approved only)
      total_hours_completed: totalHoursCompleted,
      required_hours: requiredHours,
      attendance_rate: attendanceRate,
      late_count: lateCount,
      absent_count: absentCount,
      hours_completed_ratio: hoursCompletedRatio,
      
      // Progress features
      ojt_status: 'Active', // Default status
      
      // Competency-based daily task features
      total_tasks_logged: parseInt(snap.total_tasks_logged) || 0,
      total_task_hours: parseFloat(snap.total_task_hours) || 0,
      number_of_distinct_competencies: parseInt(snap.number_of_distinct_competencies) || 0,
      
      // Individual competency hours (11 competencies)
      hours_software_development: competencyHoursMap['software_development'] || 0,
      hours_machine_learning_engineering: competencyHoursMap['machine_learning_engineering'] || 0,
      hours_it_related_research: competencyHoursMap['it_related_research'] || 0,
      hours_ux_ui_design: competencyHoursMap['user_experience_ui_design'] || 0,
      hours_information_security_analysis: competencyHoursMap['information_security_analysis'] || 0,
      hours_networking: competencyHoursMap['networking'] || 0,
      hours_technical_support: competencyHoursMap['technical_support'] || 0,
      hours_data_analysis: competencyHoursMap['data_analysis'] || 0,
      hours_customer_service: competencyHoursMap['customer_service'] || 0,
      hours_data_entry_management: competencyHoursMap['data_entry_and_management'] || 0,
      hours_office_work: competencyHoursMap['office_work'] || 0,
      
      // OJT Grading-related features
      weekly_progress_grade: weeklyProgressGrade,
      narrative_report_grade: narrativeReportGrade,
      coordinator_eval_grade: coordinatorEvalGrade,
      supervisor_eval_grade: supervisorEvalGrade,
      
      // Grade presence flags
      has_weekly_progress_grade: weeklyProgressGrade > 0 ? 1 : 0,
      has_narrative_report_grade: narrativeReportGrade > 0 ? 1 : 0,
      has_coordinator_eval_grade: coordinatorEvalGrade > 0 ? 1 : 0,
      has_supervisor_eval_grade: supervisorEvalGrade > 0 ? 1 : 0,
      
      // Chatbot engagement
      total_chatbot_queries: parseInt(snap.total_chatbot_queries) || 0,
      chatbot_queries_last_30_days: parseInt(snap.chatbot_queries_last_30_days) || 0,
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
          success: false,
          error_type: 'SERVICE_UNAVAILABLE',
          error: 'AI prediction service unavailable',
          message: 'Cannot connect to Flask AI service. Please ensure it is running.',
          snapshot: payload
        });
      }
      throw axiosError;
    }

    const prediction = aiRes.data;
    
    // Check if prediction returned an error response
    if (prediction && prediction.success === false) {
      // Map error types to appropriate HTTP status codes
      const statusCodeMap = {
        'MODEL_NOT_AVAILABLE': 503,
        'INVALID_INPUT': 400,
        'PREDICTION_ERROR': 500
      };
      
      const statusCode = statusCodeMap[prediction.error_type] || 500;
      
      return res.status(statusCode).json({
        success: false,
        error_type: prediction.error_type || 'PREDICTION_ERROR',
        error: prediction.message || 'Prediction failed',
        message: prediction.message,
        details: prediction.details,
        missing_fields: prediction.missing_fields,
        snapshot: payload
      });
    }

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
          JSON.stringify(prediction.ml_prediction),
          prediction.ml_prediction?.probability || 0,
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
    
    // Return a non-breaking response for the frontend instead of HTTP 500
    return res.json({ 
      student_id: parseInt(studentId, 10) || null,
      snapshot: null,
      ai_prediction: {
        success: false,
        error_type: 'PREDICTION_ERROR',
        error: 'Internal server error during prediction',
        message: err.message || 'Internal server error',
        ml_prediction: null
      },
      generated_at: new Date().toISOString()
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
    const { user_id, query: userQuery, response, model_used } = req.body;

    // Validation
    if (!user_id || !userQuery || !response) {
      return res.status(400).json({ 
        error: 'Missing required fields: user_id, query, and response are required' 
      });
    }

    // Convert user_id to integer if it's a string
    const userId = parseInt(user_id, 10);
    if (isNaN(userId)) {
      return res.status(400).json({ 
        error: 'Invalid user_id: must be a valid integer' 
      });
    }

    // Verify user exists before inserting
    const userCheck = await query(
      'SELECT user_id FROM users WHERE user_id = $1',
      [userId]
    );

    if (userCheck.rows.length === 0) {
      return res.status(404).json({ 
        error: `User with ID ${userId} not found` 
      });
    }

    const result = await query(
      `INSERT INTO chatbot_logs (user_id, query, response, model_used)
       VALUES ($1, $2, $3, $4)
       RETURNING *`,
      [userId, userQuery, response, model_used || 'rag-ollama']
    );

    res.status(201).json({
      message: 'Chatbot log saved successfully',
      log: result.rows[0]
    });
  } catch (error) {
    console.error('Save chatbot log error:', error);
    
    // Provide more detailed error message
    let errorMessage = 'Internal server error';
    if (error.code === '23503') {
      errorMessage = 'Foreign key violation: User does not exist';
    } else if (error.code === '23505') {
      errorMessage = 'Duplicate entry';
    } else if (error.message) {
      errorMessage = error.message;
    }
    
    // Log critical errors to database
    try {
      await query(
        `INSERT INTO api_error_logs (route, method, status_code, error_message)
         VALUES ($1, $2, $3, $4)`,
        ['/api/prediction/chatbot/logs', 'POST', 500, errorMessage]
      );
    } catch (logError) {
      console.error('Failed to log error to database:', logError);
    }
    
    res.status(500).json({ 
      error: errorMessage,
      details: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
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

