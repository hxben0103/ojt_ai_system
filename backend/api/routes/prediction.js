const express = require('express');
const router = express.Router();
const axios = require('axios');
const jwt = require('jsonwebtoken');
const { query } = require('../../config/db');

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

/**
 * Count weekday (Mon–Fri) days between two Date objects (inclusive).
 * Used to compute the actual required OJT days from the record's start/end dates.
 * Falls back to 25 if dates are missing or invalid.
 */
function countWeekdays(start, end) {
  if (!start || !end) return 25;
  const startDate = new Date(start);
  const endDate = new Date(end);
  if (isNaN(startDate) || isNaN(endDate) || startDate > endDate) return 25;
  let count = 0;
  const cur = new Date(startDate);
  while (cur <= endDate) {
    const day = cur.getDay();
    if (day !== 0 && day !== 6) count++; // skip Sunday(0) and Saturday(6)
    cur.setDate(cur.getDate() + 1);
  }
  return count > 0 ? count : 25;
}

/**
 * Map a 0-100 numeric score to the 1.0–5.0 Philippine grading equivalent.
 * Used to express task-based performance as an academic grade equivalent.
 */
function scoreToEquivalentGrade(score) {
  const s = parseFloat(score) || 0;
  if (s >= 97) return 1.00;
  if (s >= 94) return 1.25;
  if (s >= 91) return 1.50;
  if (s >= 88) return 1.75;
  if (s >= 85) return 2.00;
  if (s >= 82) return 2.25;
  if (s >= 79) return 2.50;
  if (s >= 76) return 2.75;
  if (s >= 75) return 3.00;
  if (s >= 70) return 3.50;
  if (s >= 65) return 4.00;
  return 5.00; // Below 65 = failed
}

/**
 * Shared logic to build the comprehensive student snapshot for AI prediction.
 */
async function getStudentAIPayload(studentId) {
  const snapshotResult = await query(`
    WITH 
    -- Get OJT record for required hours and duration
    ojt_info AS (
      SELECT o.required_hours, o.status, o.start_date, o.end_date, u.full_name AS student_name
      FROM ojt_records o
      JOIN users u ON o.student_id = u.user_id
      -- Treat both Ongoing and Active as current OJT records
      WHERE o.student_id = $1 AND o.status IN ('Ongoing', 'Active')
      LIMIT 1
    ),
    -- Attendance stats (CRITICAL: Only approved attendance counts)
    -- Apply the "1-30 minutes late = 2-hour penalty" rule per record:
    --   late_minutes = EXTRACT(minutes past 08:00) clamped to >= 0
    --   penalty_hours per record = 2 * CEIL(late_minutes / 30.0)
    --   credited_hours per record = MAX(0, actual_hours - penalty_hours)
    attendance_stats AS (
      SELECT 
        COALESCE(SUM(a.total_hours), 0) AS total_hours_completed,
        COALESCE(SUM(
          GREATEST(0,
            a.total_hours -
            2.0 * CEIL(
              GREATEST(0,
                EXTRACT(EPOCH FROM (
                  a.morning_in::time - '08:00:00'::time
                )) / 60.0
              ) / 30.0
            )
          )
        ), 0) AS credited_hours_completed,
        COALESCE(SUM(
          CASE
            WHEN a.morning_in::time > '08:00:00'::time THEN
              2.0 * CEIL(
                GREATEST(0,
                  EXTRACT(EPOCH FROM (
                    a.morning_in::time - '08:00:00'::time
                  )) / 60.0
                ) / 30.0
              )
            ELSE 0
          END
        ), 0) AS late_penalty_hours,
        COALESCE(COUNT(DISTINCT a.date), 0) AS days_present,
        COALESCE(COUNT(CASE WHEN a.morning_in::time > '08:00:00'::time THEN 1 END), 0) AS late_count,
        COALESCE(MAX(a.date), NULL) AS last_attendance_date
      FROM attendance a
      WHERE a.student_id = $1 AND a.status IN ('Approved', 'Pending')
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
    -- Competency total points (only approved tasks)
    competency_points AS (
      SELECT 
        c.competency_id,
        c.title,
        c.point_value,
        COALESCE(SUM(c.point_value), 0) AS total_points
      FROM competencies c
      LEFT JOIN task_competencies tc ON c.competency_id = tc.competency_id
      LEFT JOIN ojt_daily_tasks t ON tc.task_id = t.task_id 
        AND t.student_id = $1 
        AND t.status = 'Approved'
      GROUP BY c.competency_id, c.title, c.point_value
    ),
    wpr_computed AS (
      SELECT
        CASE
          WHEN COUNT(*) > 0
            THEN ROUND(AVG(point_value)::NUMERIC, 2)
          ELSE 0
        END AS wpr_score
      FROM competency_points
      WHERE total_points > 0
    ),
    -- Task Score: Daily average → then average of daily averages
    -- Step 1: For each day, average the point_value of all tasks logged that day
    -- Step 2: Average those daily averages to get the final score (= WPR input)
    task_score_computed AS (
      SELECT
        CASE
          WHEN COUNT(*) > 0
            THEN ROUND(AVG(daily_avg_score), 2)
          ELSE 0
        END AS avg_task_score
      FROM (
        SELECT
          DATE(t.created_at) AS task_date,
          AVG(c.point_value) AS daily_avg_score
        FROM ojt_daily_tasks t
        INNER JOIN task_competencies tc ON t.task_id = tc.task_id
        INNER JOIN competencies c ON tc.competency_id = c.competency_id
        WHERE t.student_id = $1 AND t.status = 'Approved'
        GROUP BY DATE(t.created_at)
      ) daily_scores
    ),
    -- NR: Narrative Report (20%)
    narrative_eval AS (
      SELECT COALESCE(AVG(e.total_score), 0) AS avg_score
      FROM evaluations e
      WHERE e.student_id = $1
        AND (
          e.evaluation_type = 'NR'
          OR (e.evaluation_type IS NULL AND e.supervisor_id NOT IN (
            SELECT user_id FROM users WHERE role IN ('Coordinator', 'Supervisor')
          ))
        )
    ),
    -- CE: Coordinator Evaluation (20%)
    coordinator_eval AS (
      SELECT COALESCE(AVG(e.total_score), 0) AS avg_score
      FROM evaluations e
      LEFT JOIN users u ON e.supervisor_id = u.user_id
      WHERE e.student_id = $1
        AND (
          e.evaluation_type = 'CE'
          OR (e.evaluation_type IS NULL AND u.role = 'Coordinator')
        )
    ),
    -- SE: Supervisor Evaluation (40%) — given on the last day
    supervisor_eval AS (
      SELECT COALESCE(AVG(e.total_score), 0) AS avg_score
      FROM evaluations e
      LEFT JOIN users u ON e.supervisor_id = u.user_id
      WHERE e.student_id = $1
        AND (
          e.evaluation_type = 'SE'
          OR (e.evaluation_type IS NULL AND u.role = 'Supervisor')
        )
    ),
    -- Chatbot engagement
    chatbot_stats AS (
      SELECT 
        COUNT(*) AS total_queries,
        COUNT(CASE WHEN timestamp >= CURRENT_DATE - INTERVAL '30 days' THEN 1 END) AS queries_last_30_days
      FROM chatbot_logs
      WHERE user_id = $1
    ),
    -- Integrity stats (from latest checkin in last 14 days)
    integrity_stats AS (
      SELECT
        inside_geofence,
        distance_m,
        accuracy_m,
        trust_flags,
        CASE WHEN attendance_image IS NOT NULL THEN true ELSE false END AS has_photo
      FROM attendance
      WHERE student_id = $1 AND date >= CURRENT_DATE - INTERVAL '14 days'
      ORDER BY date DESC, morning_in DESC
      LIMIT 1
    ),
    recent_flags AS (
      SELECT COUNT(*) AS count
      FROM attendance
      WHERE student_id = $1 AND date >= CURRENT_DATE - INTERVAL '7 days'
        AND (inside_geofence = false OR trust_flags IS NOT NULL)
    ),
    -- Consecutive absence detection using islands-and-gaps algorithm
    -- Compares all weekdays in OJT period vs days the student was actually present
    consecutive_absence_stats AS (
      WITH
        ojt_range AS (
          SELECT
            start_date,
            LEAST(CURRENT_DATE, COALESCE(end_date, CURRENT_DATE)) AS effective_end
          FROM ojt_records
          WHERE student_id = $1 AND status IN ('Ongoing', 'Active')
          LIMIT 1
        ),
        all_weekdays AS (
          SELECT d::date AS day
          FROM generate_series(
            (SELECT start_date FROM ojt_range),
            (SELECT effective_end FROM ojt_range),
            '1 day'
          ) d
          WHERE EXTRACT(DOW FROM d) NOT IN (0, 6)  -- exclude Sat/Sun
        ),
        present_dates AS (
          SELECT DISTINCT date
          FROM attendance
          WHERE student_id = $1 AND status IN ('Approved', 'Pending')
        ),
        -- Mark each weekday: 1 = absent, 0 = present
        day_flags AS (
          SELECT
            w.day,
            CASE WHEN p.date IS NULL THEN 1 ELSE 0 END AS is_absent,
            ROW_NUMBER() OVER (ORDER BY w.day) AS rn
          FROM all_weekdays w
          LEFT JOIN present_dates p ON p.date = w.day
        ),
        -- Islands: assign the same group number to each consecutive absent streak
        absent_islands AS (
          SELECT
            day, rn,
            rn - ROW_NUMBER() OVER (ORDER BY day) AS grp
          FROM day_flags
          WHERE is_absent = 1
        ),
        -- Streak lengths + start/end dates
        streaks AS (
          SELECT
            grp,
            COUNT(*) AS streak_len,
            MIN(day) AS streak_start,
            MAX(day) AS streak_end
          FROM absent_islands
          GROUP BY grp
        )
      SELECT
        COALESCE(MAX(streak_len), 0) AS max_consecutive_absences,
        -- Current streak = the streak whose last absent day is within the last 3 weekdays
        COALESCE((
          SELECT streak_len FROM streaks
          WHERE streak_end >= CURRENT_DATE - INTERVAL '4 days'
          ORDER BY streak_end DESC
          LIMIT 1
        ), 0) AS current_absence_streak
      FROM streaks
    ),
    -- Trend stats (hours in last 7 days vs prev 7 days)
    trend_stats AS (
      SELECT
        COALESCE(SUM(CASE WHEN date >= CURRENT_DATE - INTERVAL '7 days' THEN total_hours ELSE 0 END), 0) AS hours_last_7,
        COALESCE(SUM(CASE WHEN date >= CURRENT_DATE - INTERVAL '14 days' AND date < CURRENT_DATE - INTERVAL '7 days' THEN total_hours ELSE 0 END), 0) AS hours_prev_7
      FROM attendance
      WHERE student_id = $1 AND status IN ('Approved', 'Pending')
    )
    SELECT 
      (SELECT student_name FROM ojt_info) AS student_name,
      (SELECT COALESCE(required_hours, 300) FROM ojt_info) AS required_hours,
      (SELECT start_date FROM ojt_info) AS ojt_start_date,
      (SELECT end_date   FROM ojt_info) AS ojt_end_date,
      (SELECT total_hours_completed FROM attendance_stats) AS total_hours_completed,
      (SELECT credited_hours_completed FROM attendance_stats) AS credited_hours_completed,
      (SELECT late_penalty_hours FROM attendance_stats) AS late_penalty_hours,
      (SELECT days_present FROM attendance_stats) AS days_present,
      (SELECT late_count FROM attendance_stats) AS late_count,
      (SELECT total_tasks_logged FROM task_stats) AS total_tasks_logged,
      (SELECT total_task_hours FROM task_stats) AS total_task_hours,
      (SELECT number_of_distinct_competencies FROM task_stats) AS number_of_distinct_competencies,
      (SELECT wpr_score FROM wpr_computed) AS wpr_eval_score,
      (SELECT avg_task_score FROM task_score_computed) AS avg_task_score,
      (SELECT avg_score FROM coordinator_eval) AS coordinator_eval_score,
      (SELECT avg_score FROM supervisor_eval) AS supervisor_eval_score,
      (SELECT avg_score FROM narrative_eval) AS narrative_eval_score,
      (SELECT total_queries FROM chatbot_stats) AS total_chatbot_queries,
      (SELECT queries_last_30_days FROM chatbot_stats) AS chatbot_queries_last_30_days,
      (SELECT row_to_json(i) FROM integrity_stats i) AS integrity_data,
      (SELECT count FROM recent_flags) AS recent_flags_count,
      (SELECT max_consecutive_absences FROM consecutive_absence_stats) AS max_consecutive_absences,
      (SELECT current_absence_streak FROM consecutive_absence_stats) AS current_absence_streak,
      (SELECT row_to_json(t) FROM trend_stats t) AS trend_data,
      (SELECT json_agg(json_build_object('title', title, 'points', total_points, 'point_value', point_value)) FROM competency_points) AS competency_points_json
  `, [studentId]);

  if (!snapshotResult.rows || snapshotResult.rows.length === 0 || !snapshotResult.rows[0].student_name) {
    return null;
  }

  const snap = snapshotResult.rows[0];
  const requiredHours = parseFloat(snap.required_hours) || 300;
  const totalHoursCompleted = parseFloat(snap.total_hours_completed) || 0;
  const creditedHoursCompleted = parseFloat(snap.credited_hours_completed) || 0;
  const latePenaltyHours = parseFloat(snap.late_penalty_hours) || 0;
  const daysPresent = parseFloat(snap.days_present) || 0;
  const lateCount = parseInt(snap.late_count) || 0;

  // OJT Timeframe
  const ojtStartDate = snap.ojt_start_date ? new Date(snap.ojt_start_date).toISOString().split('T')[0] : null;
  const ojtEndDate = snap.ojt_end_date ? new Date(snap.ojt_end_date).toISOString().split('T')[0] : null;
  const totalOjtDays = countWeekdays(snap.ojt_start_date, snap.ojt_end_date);
  const today = new Date();
  const endDateObj = snap.ojt_end_date ? new Date(snap.ojt_end_date) : null;
  const daysRemaining = endDateObj ? Math.max(0, countWeekdays(today, endDateObj)) : null;

  const requiredDays = totalOjtDays;
  const attendanceRate = requiredDays > 0 ? Math.min((daysPresent / requiredDays) * 100, 100) : 0;
  const absentCount = Math.max(0, requiredDays - daysPresent);
  // Use credited hours (after late penalty) for the progress ratio sent to the AI
  const hoursCompletedRatio = requiredHours > 0 ? creditedHoursCompleted / requiredHours : 0;

  const competencyPointsJson = snap.competency_points_json || [];
  const competencyPointsMap = {};
  competencyPointsJson.forEach(item => {
    const title = item.title || '';
    const points = parseFloat(item.points) || 0;
    // Improved normalization to ensure consistency with hardcoded keys (e.g. IT-Related -> it_related)
    // 1. Lowercase, 2. Replace non-alphanum with underscores, 3. Collapse multiple __, 4. Trim _
    const featureName = title.toLowerCase()
                             .replace(/[^a-z0-9]+/g, '_')
                             .replace(/^_+|_+$/g, '');
    competencyPointsMap[featureName] = points;
  });

  // Task-based score: running average of each day's avg task scores (from task_score_computed CTE)
  // Each day → avg(competency point_values of tasks logged) → accumulate → divide by number of days
  const totalTaskPoints = parseFloat(snap.avg_task_score) || 0;

  // WPR = (running avg daily task score + attendance rate) / 2
  // Combines task skill performance + attendance into a single 0-100 WPR score
  const weeklyProgressGrade = Math.min(100, Math.round(((totalTaskPoints + attendanceRate) / 2) * 100) / 100);

  const narrativeReportGrade = parseFloat(snap.narrative_eval_score) || 0;
  const coordinatorEvalGrade = parseFloat(snap.coordinator_eval_score) || 0;
  const supervisorEvalGrade = parseFloat(snap.supervisor_eval_score) || 0;

  // Equivalent grade (1.0–5.0 PH scale) derived from the task score component
  const equivalentGrade = scoreToEquivalentGrade(totalTaskPoints);

  const payload = {
    student_name: snap.student_name,
    // --- OJT Timeframe ---
    ojt_start_date: ojtStartDate,
    ojt_end_date: ojtEndDate,
    total_ojt_days: totalOjtDays,
    days_remaining: daysRemaining,
    // --- Hours ---
    total_hours_completed: totalHoursCompleted,
    credited_hours_completed: creditedHoursCompleted,  // after 1-30min=2hr penalty
    late_penalty_hours: latePenaltyHours,
    required_hours: requiredHours,
    // --- Attendance ---
    attendance_rate: attendanceRate,
    late_count: lateCount,
    absent_count: absentCount,
    hours_completed_ratio: hoursCompletedRatio,  // uses credited hours
    ojt_status: 'Active',
    // --- Tasks ---
    total_tasks_logged: parseInt(snap.total_tasks_logged) || 0,
    total_task_hours: parseFloat(snap.total_task_hours) || 0,
    number_of_distinct_competencies: parseInt(snap.number_of_distinct_competencies) || 0,
    // --- Task Score & Equivalent Grade ---
    total_task_points: totalTaskPoints,
    equivalent_grade: equivalentGrade,
    // --- Competency Cumulative Points ---
    // (Still using "hours_" keys for model compatibility, but value is now accumulated points)
    hours_software_development: competencyPointsMap['software_development'] || 0,
    hours_machine_learning_engineering: competencyPointsMap['machine_learning_engineering'] || 0,
    hours_it_related_research: competencyPointsMap['it_related_research'] || 0,
    hours_ux_ui_design: competencyPointsMap['user_experience_ui_design'] || 0,
    hours_information_security_analysis: competencyPointsMap['information_security_analysis'] || 0,
    hours_networking: competencyPointsMap['networking'] || 0,
    hours_technical_support: competencyPointsMap['technical_support'] || 0,
    hours_data_analysis: competencyPointsMap['data_analysis'] || 0,
    hours_customer_service: competencyPointsMap['customer_service'] || 0,
    hours_data_entry_management: competencyPointsMap['data_entry_and_management'] || 0,
    hours_office_work: competencyPointsMap['office_work'] || 0,
    // --- Evaluation Grades ---
    weekly_progress_grade: weeklyProgressGrade,
    narrative_report_grade: narrativeReportGrade,
    coordinator_eval_grade: coordinatorEvalGrade,
    supervisor_eval_grade: supervisorEvalGrade,
    has_weekly_progress_grade: weeklyProgressGrade > 0 ? 1 : 0,
    has_narrative_report_grade: narrativeReportGrade > 0 ? 1 : 0,
    has_coordinator_eval_grade: coordinatorEvalGrade > 0 ? 1 : 0,
    has_supervisor_eval_grade: supervisorEvalGrade > 0 ? 1 : 0,
    // --- Engagement ---
    total_chatbot_queries: parseInt(snap.total_chatbot_queries) || 0,
    chatbot_queries_last_30_days: parseInt(snap.chatbot_queries_last_30_days) || 0,
    // --- Integrity ---
    inside_geofence: snap.integrity_data?.inside_geofence !== false,
    distance_m: parseFloat(snap.integrity_data?.distance_m) || 0.0,
    accuracy_m: parseFloat(snap.integrity_data?.accuracy_m) || 10.0,
    trust_flags: snap.integrity_data?.trust_flags || "",
    has_photo: snap.integrity_data?.has_photo !== false,
    recent_flags_count: parseInt(snap.recent_flags_count) || 0,
    // --- Consecutive Absence Alert (separate from integrity flags) ---
    max_consecutive_absences: parseInt(snap.max_consecutive_absences) || 0,
    current_absence_streak: parseInt(snap.current_absence_streak) || 0,
    // Alert fires when student has been absent 3+ consecutive weekdays (academic risk, not integrity)
    consecutive_absence_alert: (parseInt(snap.max_consecutive_absences) || 0) >= 3,
  };

  const h7 = parseFloat(snap.trend_data?.hours_last_7) || 0;
  const p7 = parseFloat(snap.trend_data?.hours_prev_7) || 0;

  if (h7 > p7 * 1.15) {
    payload.trend_status = 'improving';
    payload.trend_reason = `Hours logged increased by >15% compared to previous week (${h7} vs ${p7})`;
  } else if (h7 < p7 * 0.85) {
    payload.trend_status = 'declining';
    payload.trend_reason = `Hours logged decreased by >15% compared to previous week (${h7} vs ${p7})`;
  } else {
    payload.trend_status = 'stable';
    payload.trend_reason = `Consistent performance logic maintained (${h7} vs ${p7})`;
  }

  return payload;
}

/**
 * Shared logic to call the Flask AI Service.
 */
async function callFlaskAI(payload) {
  const flaskUrl = process.env.FLASK_AI_URL || 'http://127.0.0.1:5000';
  const response = await axios.post(`${flaskUrl}/predict`, payload, {
    timeout: 300000, // Increased to 5 minutes for batch reliability
    headers: { 'Content-Type': 'application/json' }
  });
  return response.data;
}

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
router.get('/insights', authenticateToken, async (req, res) => {
  try {
    const { student_id } = req.query;
    const { role, user_id } = req.user;

    let sql = `
      SELECT a.*, u.full_name AS student_name
      FROM ai_insights a
      JOIN users u ON a.student_id = u.user_id
      -- Join OJT records for coordinator filtering
      LEFT JOIN ojt_records o ON a.student_id = o.student_id AND o.status IN ('Ongoing', 'Active')
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
      sql += ` AND a.student_id = $${paramCount}`;
      params.push(student_id);
      paramCount++;
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
router.get('/performance', authenticateToken, async (req, res) => {
  try {
    const { student_id } = req.query;
    const { role, user_id } = req.user;

    if (!student_id) {
      return res.status(400).json({ error: 'student_id is required' });
    }

    // Data Isolation Check
    if (role === 'Coordinator') {
      const accessCheck = await query(
        "SELECT record_id FROM ojt_records WHERE student_id = $1 AND coordinator_id = $2 AND status IN ('Ongoing', 'Active') LIMIT 1",
        [student_id, user_id]
      );
      if (accessCheck.rows.length === 0) {
        return res.status(403).json({ error: 'Access Denied' });
      }
    }

    const payload = await getStudentAIPayload(student_id);
    if (!payload) return res.status(404).json({ error: 'Student data not found' });

    const prediction = await callFlaskAI(payload);

    res.json({
      performance: prediction,
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
    if (!student_id) return res.status(400).json({ error: 'student_id is required' });

    const payload = await getStudentAIPayload(student_id);
    if (!payload) return res.status(404).json({ error: 'Student data not found' });

    const prediction = await callFlaskAI(payload);

    const insertResult = await query(
      `INSERT INTO ai_insights (student_id, model_name, insight_type, result, confidence, input_data)
       VALUES ($1, $2, $3, $4, $5, $6)
       RETURNING *`,
      [
        student_id,
        'Performance Prediction Model',
        'performance_prediction',
        JSON.stringify(prediction),
        prediction.confidence || prediction.ml_prediction?.probability || 0,
        JSON.stringify({ ...payload, generated_via: 'api_generate' })
      ]
    );

    res.status(201).json({
      message: 'Performance prediction generated and saved',
      prediction: prediction,
      insight: insertResult.rows[0]
    });
  } catch (error) {
    console.error('Generate performance error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get risk assessment for student
router.get('/risk-assessment/:student_id', authenticateToken, async (req, res) => {
  try {
    const { student_id } = req.params;
    const { role, user_id } = req.user;

    // Data Isolation: Check access
    if (role === 'Coordinator') {
      const accessCheck = await query(
        "SELECT record_id FROM ojt_records WHERE student_id = $1 AND coordinator_id = $2 AND status IN ('Ongoing', 'Active') LIMIT 1",
        [student_id, user_id]
      );
      if (accessCheck.rows.length === 0) {
        return res.status(403).json({ error: 'Access Denied', message: 'You can only view risk assessment for students assigned to you.' });
      }
    }

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
router.get('/at-risk', authenticateToken, async (req, res) => {
  try {
    const { level } = req.query; // 'High', 'Medium', or undefined for all
    const { role, user_id } = req.user;

    // Data Isolation: Filter by coordinator if role is Coordinator
    let result;
    if (role === 'Coordinator') {
      // get_at_risk_students doesn't filter by coordinator, so we filter the results
      const allAtRisk = await query('SELECT * FROM get_at_risk_students($1)', [level || null]);
      
      // Filter by coordinator_id in ojt_records
      const coordinatorStudents = await query(
        "SELECT student_id FROM ojt_records WHERE coordinator_id = $1 AND status IN ('Ongoing', 'Active')",
        [user_id]
      );
      const allowedIds = new Set(coordinatorStudents.rows.map(r => r.student_id));
      
      const filteredResult = allAtRisk.rows.filter(r => allowedIds.has(r.student_id));
      
      return res.json({
        at_risk_students: filteredResult,
        count: filteredResult.length,
        risk_level_filter: level || 'All'
      });
    }

    result = await query(
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
    // 1) Get all active students
    const activeStudents = await query(`
      SELECT DISTINCT u.user_id
      FROM users u
      JOIN ojt_records o ON u.user_id = o.student_id
      WHERE u.role = 'Student' AND o.status IN ('Ongoing', 'Active')
    `);

    const results = [];
    const errors = [];

    // 2) Process each student (Smart AI Prediction)
    for (const row of activeStudents.rows) {
      const studentId = row.user_id;
      try {
        const payload = await getStudentAIPayload(studentId);
        if (!payload) continue;

        const prediction = await callFlaskAI(payload);

        await query(
          `INSERT INTO ai_insights (student_id, model_name, insight_type, result, confidence, input_data)
           VALUES ($1, $2, $3, $4, $5, $6)`,
          [
            studentId,
            'Performance Prediction Model (Batch)',
            'performance_prediction',
            JSON.stringify(prediction),
            prediction.confidence || prediction.ml_prediction?.probability || 0,
            JSON.stringify({ ...payload, batch_job: true })
          ]
        );

        results.push({ studentId, status: 'Success' });
      } catch (err) {
        console.error(`Batch error for student ${studentId}:`, err.message);
        errors.push({ studentId, error: err.message });
      }
    }

    res.json({
      message: `Batch job complete: ${results.length} succeeded, ${errors.length} failed`,
      results,
      errors,
      generated_at: new Date().toISOString()
    });
  } catch (error) {
    console.error('Batch prediction error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Daily risk prediction for a student
router.get('/daily/:studentId', authenticateToken, async (req, res) => {
  const studentId = req.params.studentId;
  const { role, user_id } = req.user;

  // Data Isolation: Check access
  if (role === 'Coordinator') {
    const accessCheck = await query(
      "SELECT record_id FROM ojt_records WHERE student_id = $1 AND coordinator_id = $2 AND status IN ('Ongoing', 'Active') LIMIT 1",
      [studentId, user_id]
    );
    if (accessCheck.rows.length === 0) {
      return res.status(403).json({ error: 'Access Denied', message: 'You can only run predictions for students assigned to you.' });
    }
  }

  try {
    // Check if we have a recent prediction (last 4 hours) to avoid overwhelming the LLM
    const recentPrediction = await query(
      `SELECT result, created_at 
       FROM ai_insights 
       WHERE student_id = $1 
         AND insight_type = 'daily_risk_prediction'
         AND created_at >= NOW() - INTERVAL '4 hours'
       ORDER BY created_at DESC 
       LIMIT 1`,
      [studentId]
    );

    if (recentPrediction.rows.length > 0) {
      const cached = recentPrediction.rows[0];
      return res.json({
        student_id: parseInt(studentId),
        cached: true,
        ai_prediction: typeof cached.result === 'string' ? JSON.parse(cached.result) : cached.result,
        generated_at: cached.created_at
      });
    }

    // 1) Build snapshot
    const payload = await getStudentAIPayload(studentId);
    if (!payload) {
      return res.status(404).json({ error: 'No data for this student' });
    }

    // 2) Call AI
    let prediction;
    try {
      prediction = await callFlaskAI(payload);
    } catch (error) {
      console.error('Flask AI service error:', error.message);
      if (error.code === 'ECONNREFUSED' || error.code === 'ETIMEDOUT') {
        return res.status(503).json({
          success: false,
          error_type: 'SERVICE_UNAVAILABLE',
          error: 'AI prediction service unavailable',
          message: 'Cannot connect to Flask AI service.',
          snapshot: payload
        });
      }
      throw error;
    }

    // 3) Handle AI Error Response
    if (prediction && prediction.success === false) {
      const statusCodeMap = { 'MODEL_NOT_AVAILABLE': 503, 'INVALID_INPUT': 400 };
      return res.status(statusCodeMap[prediction.error_type] || 500).json({
        student_id: parseInt(studentId),
        success: false,
        ai_prediction: prediction,
        snapshot: payload
      });
    }

    // 4) Save to ai_insights
    try {
      await query(
        `INSERT INTO ai_insights (student_id, model_name, insight_type, result, confidence, input_data)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [
          studentId,
          'Daily Risk Prediction Ensemble',
          'daily_risk_prediction',
          JSON.stringify(prediction),
          prediction.confidence || prediction.ml_prediction?.probability || 0,
          JSON.stringify(payload)
        ]
      );
    } catch (insertError) {
      console.warn('Failed to save insight:', insertError.message);
    }

    // Attach trend manually as backend carries specific trend logic
    const finalPrediction = {
      ...prediction,
      trend: {
        status: payload.trend_status,
        reason: payload.trend_reason
      }
    };

    return res.json({
      student_id: parseInt(studentId),
      snapshot: payload,
      ai_prediction: finalPrediction,
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

// Chatbot Interaction Proxy Endpoint (Injects Student Competencies)
router.post('/chat', async (req, res) => {
  try {
    const { message, session_id, student_id, stream } = req.body;

    let student_data = null;
    if (student_id) {
      // Fetch competency hours for skill gap and career match analysis
      const compResult = await query(`
        SELECT 
          c.title,
          COALESCE(SUM(t.hours_worked), 0) AS hours
        FROM competencies c
        LEFT JOIN task_competencies tc ON c.competency_id = tc.competency_id
        LEFT JOIN ojt_daily_tasks t ON tc.task_id = t.task_id 
          AND t.student_id = $1 
          AND t.status = 'Approved'
        GROUP BY c.competency_id, c.title
      `, [student_id]);

      const competencies = {};
      compResult.rows.forEach(row => {
        const key = row.title.toLowerCase().replace(/[^a-z0-9]+/g, '_');
        competencies[key] = parseFloat(row.hours) || 0;
      });

      student_data = { competencies };
    }

    const aiServiceUrl = process.env.AI_SERVICE_URL || 'http://127.0.0.1:5000';
    
    try {
      if (stream === true) {
        // Handle streaming request
        const response = await axios({
          method: 'post',
          url: `${aiServiceUrl}/chat`,
          data: { message, session_id, student_data, stream: true },
          responseType: 'stream',
          timeout: 120000
        });

        res.setHeader('Content-Type', 'application/x-ndjson');
        res.setHeader('Transfer-Encoding', 'chunked');
        response.data.pipe(res);
      } else {
        // Handle standard non-streaming request
        const response = await axios.post(`${aiServiceUrl}/chat`, {
          message,
          session_id,
          student_data,
          stream: false
        }, { timeout: 120000 });
        
        return res.status(response.status).json(response.data);
      }
    } catch (axiosError) {
      console.error('AI Service communication error:', axiosError.message);
      return res.status(503).json({
        success: false,
        error_type: 'CHATBOT_SERVICE_UNAVAILABLE',
        message: 'AI chat service is currently down.'
      });
    }
  } catch (error) {
    console.error('Chat endpoint error:', error);
    res.status(500).json({
      success: false,
      error_type: 'INTERNAL_ERROR',
      message: 'Failed to process chat request.'
    });
  }
});

// Chatbot logs
router.get('/chatbot/logs', authenticateToken, async (req, res) => {
  try {
    const { user_id: targetStudentId } = req.query;
    const { role, user_id: loggedInUserId } = req.user;

    // Data Isolation: Coordinators can only see their students' logs
    if (role === 'Coordinator' && targetStudentId) {
       const accessCheck = await query(
        "SELECT record_id FROM ojt_records WHERE student_id = $1 AND coordinator_id = $2 AND status IN ('Ongoing', 'Active') LIMIT 1",
        [targetStudentId, loggedInUserId]
      );
      if (accessCheck.rows.length === 0) {
        return res.status(403).json({ error: 'Access Denied', message: 'You can only view chatbot logs for students assigned to you.' });
      }
    }

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

// Get AI Evaluation Metrics (Defense Ready)
router.get('/evaluation-metrics', async (req, res) => {
  try {
    // 1. Fetch data from ai_evaluations table
    const evalResult = await query(`
      SELECT 
        COUNT(*) as total_predictions,
        SUM(CASE WHEN predicted_risk = actual_outcome THEN 1 ELSE 0 END) as correct_predictions,
        SUM(CASE WHEN predicted_risk = 'HIGH' AND actual_outcome = 'Failed' THEN 1 ELSE 0 END) as true_positives,
        SUM(CASE WHEN predicted_risk = 'HIGH' AND actual_outcome != 'Failed' THEN 1 ELSE 0 END) as false_positives,
        SUM(CASE WHEN predicted_risk != 'HIGH' AND actual_outcome = 'Failed' THEN 1 ELSE 0 END) as false_negatives,
        COUNT(CASE WHEN jsonb_array_length(flags_caught) > 0 THEN 1 END) as flagged_cases
      FROM ai_evaluations
      WHERE actual_outcome != 'Pending'
    `);

    if (evalResult.rows.length === 0 || evalResult.rows[0].total_predictions === '0') {
      return res.json({
        message: "No resolved AI evaluations recorded yet. Run predictions and log actual outcomes to generate metrics.",
        model_accuracy: 0,
        precision: 0,
        recall: 0,
        total_predictions: 0,
        flagged_cases: 0
      });
    }

    const metrics = evalResult.rows[0];
    const tp = parseInt(metrics.true_positives) || 0;
    const fp = parseInt(metrics.false_positives) || 0;
    const fn = parseInt(metrics.false_negatives) || 0;
    const correct = parseInt(metrics.correct_predictions) || 0;
    const total = parseInt(metrics.total_predictions) || 0;

    const precision = (tp + fp) > 0 ? (tp / (tp + fp)) : 0;
    const recall = (tp + fn) > 0 ? (tp / (tp + fn)) : 0;
    const accuracy = total > 0 ? (correct / total) : 0;

    res.json({
      model_accuracy: accuracy,
      precision: precision,
      recall: recall,
      total_predictions: total,
      flagged_cases: parseInt(metrics.flagged_cases) || 0,
      generated_at: new Date().toISOString()
    });
  } catch (error) {
    console.error('Get evaluation metrics error:', error);
    res.status(500).json({ error: 'Internal server error while computing metrics.' });
  }
});

// Suggest competency based on task description
router.post('/suggest-competency', async (req, res) => {
  try {
    const { description } = req.body;

    if (!description) {
      return res.status(400).json({ error: 'Description is required' });
    }

    const flaskUrl = process.env.FLASK_AI_URL || 'http://localhost:5000';
    
    const response = await axios.post(`${flaskUrl}/suggest-competency`, {
      description
    });

    res.json(response.data);
  } catch (error) {
    console.error('Suggest competency error:', error.message);
    res.status(500).json({ 
      success: false, 
      error: 'Failed to get competency suggestion',
      message: error.message 
    });
  }
});

// =====================================================
// GET /api/prediction/history/:studentId
// Returns historical AI predictions for trend graph
// =====================================================
router.get('/prediction/history/:studentId', authenticateToken, async (req, res) => {
  try {
    const { studentId } = req.params;
    const currentUser = req.user;

    // Access check
    if (currentUser.role === 'Student' && currentUser.user_id != studentId) {
      return res.status(403).json({ error: 'Access denied' });
    }

    const result = await query(
      `SELECT
         id,
         student_id,
         insight_date,
         forecasted_grade,
         risk_level,
         created_at
       FROM ai_insights
       WHERE student_id = $1
         AND forecasted_grade IS NOT NULL
       ORDER BY insight_date DESC, created_at DESC
       LIMIT 10`,
      [studentId]
    );

    const history = result.rows.map(row => ({
      id: row.id,
      studentId: row.student_id,
      date: row.insight_date || row.created_at,
      forecastedGrade: parseFloat(row.forecasted_grade) || 0,
      riskLevel: row.risk_level || 'UNKNOWN'
    })).reverse(); // Oldest first so chart renders left-to-right

    res.json({ history });
  } catch (error) {
    console.error('Get prediction history error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
