const express = require('express');
const router = express.Router();
const { query } = require('../../config/db');
const authenticateToken = require('../middleware/auth');

/**
 * Coordinator Analytics API
 *
 * Aggregates:
 * - Approved attendance progress
 * - AI risk levels (HIGH / MEDIUM / LOW)
 * - Competency exposure (hours & task counts)
 * - Evaluation-based performance (WPR, NR, CE, SE, projected final grade)
 *
 * Intended for coordinator & supervisor dashboards.
 */

// Helper to safely parse numeric DB values
function toNumber(value, fallback = 0) {
  const n = parseFloat(value);
  return Number.isNaN(n) ? fallback : n;
}

/**
 * GET /api/analytics/coordinator/overview
 *
 * Returns a high-level overview for all active OJT students:
 * - per_student: array of student analytics
 * - risk_summary: counts of HIGH / MEDIUM / LOW
 * - attendance_summary: averages and completion rates
 * - competency_summary: top competencies by total hours
 * - evaluation_summary: avg WPR / NR / CE / SE and projected final grade
 */
router.get('/analytics/coordinator/overview', authenticateToken, async (req, res) => {
  try {
    console.log('📊 [Coordinator Analytics] Fetching overview...');
    const { role, user_id } = req.user;
    
    // Data Isolation: Enforce coordinator_id if role is Coordinator
    let currentCoordinatorId = req.query.coordinator_id;
    if (role === 'Coordinator') {
      currentCoordinatorId = user_id;
    }

    let baseResult;
    try {
      // 1) Base set of active OJT students with required hours & names
      const baseParams = [];
      let coordFilter = '';
      if (currentCoordinatorId) {
        baseParams.push(currentCoordinatorId);
        coordFilter = `AND o.coordinator_id = $${baseParams.length}`;
      }
      baseResult = await query(
        `
      WITH active_ojt AS (
        SELECT 
          o.record_id,
          o.student_id,
          o.required_hours,
          o.status,
          u.full_name AS student_name,
          -- Dynamic expected days based on 8-hour workday
          CEIL(o.required_hours / 8.0) AS expected_days
        FROM ojt_records o
        JOIN users u ON o.student_id = u.user_id
        WHERE o.status IN ('Ongoing', 'Active') ${coordFilter}
      ),
      attendance_agg AS (
        SELECT 
          a.student_id,
          COALESCE(SUM(a.total_hours), 0)                           AS total_hours_completed,
          COALESCE(COUNT(DISTINCT a.date), 0)                       AS days_present,
          COALESCE(COUNT(CASE WHEN a.morning_in IS NOT NULL AND a.morning_in > '08:00:00' THEN 1 END), 0) AS late_count
        FROM attendance a
        WHERE a.status = 'Approved'  -- Only count verified attendance (time-in auto-approves)
        GROUP BY a.student_id
      ),
      -- Unified WPR logic: Σ(hours * point_value) / Σ(hours)
      task_agg AS (
        SELECT 
          t.student_id,
          COUNT(DISTINCT t.task_id)                                 AS total_tasks_logged,
          COALESCE(SUM(t.hours_worked), 0)                          AS total_task_hours,
          COUNT(DISTINCT tc.competency_id)                          AS number_of_distinct_competencies,
          CASE 
            WHEN SUM(t.hours_worked) > 0 
            THEN ROUND(SUM(t.hours_worked * c.point_value)::NUMERIC / SUM(t.hours_worked), 2)
            ELSE 0 
          END AS wpr_score
        FROM ojt_daily_tasks t
        LEFT JOIN task_competencies tc ON t.task_id = tc.task_id
        LEFT JOIN competencies c ON tc.competency_id = c.competency_id
        WHERE t.status = 'Approved'
        GROUP BY t.student_id
      ),
      eval_agg AS (
        SELECT 
          e.student_id,
          AVG(CASE WHEN e.evaluation_type = 'CE' OR (e.evaluation_type IS NULL AND u.role = 'Coordinator') THEN e.total_score END) AS coordinator_eval_grade,
          AVG(CASE WHEN e.evaluation_type = 'SE' OR (e.evaluation_type IS NULL AND u.role = 'Supervisor') THEN e.total_score END) AS supervisor_eval_grade,
          AVG(CASE WHEN e.evaluation_type = 'NR' OR (e.evaluation_type IS NULL AND u.role NOT IN ('Coordinator', 'Supervisor')) THEN e.total_score END) AS narrative_report_grade
        FROM evaluations e
        LEFT JOIN users u ON e.supervisor_id = u.user_id
        GROUP BY e.student_id
      )
      SELECT 
        a_ojt.student_id,
        a_ojt.student_name,
        a_ojt.required_hours,
        a_ojt.expected_days,
        COALESCE(att.total_hours_completed, 0)              AS total_hours_completed,
        COALESCE(att.days_present, 0)                       AS days_present,
        COALESCE(att.late_count, 0)                         AS late_count,
        COALESCE(tsk.total_tasks_logged, 0)                 AS total_tasks_logged,
        COALESCE(tsk.total_task_hours, 0)                   AS total_task_hours,
        COALESCE(tsk.number_of_distinct_competencies, 0)    AS number_of_distinct_competencies,
        COALESCE(tsk.wpr_score, 0)                          AS weekly_progress_grade,
        COALESCE(ev.coordinator_eval_grade, 0)              AS coordinator_eval_grade,
        COALESCE(ev.supervisor_eval_grade, 0)               AS supervisor_eval_grade,
        COALESCE(ev.narrative_report_grade, 0)              AS narrative_report_grade
      FROM active_ojt a_ojt
      LEFT JOIN attendance_agg att ON att.student_id = a_ojt.student_id
      LEFT JOIN task_agg tsk ON tsk.student_id = a_ojt.student_id
      LEFT JOIN eval_agg ev ON ev.student_id = a_ojt.student_id
      ORDER BY a_ojt.student_name ASC
      `,
        baseParams
      );
    } catch (baseQueryError) {
      console.error('❌ [Coordinator Analytics] Base query failed:', baseQueryError);
      console.error('❌ [Coordinator Analytics] Error details:', {
        message: baseQueryError.message,
        code: baseQueryError.code,
        detail: baseQueryError.detail,
        hint: baseQueryError.hint,
        position: baseQueryError.position
      });
      throw new Error(`Failed to fetch student data: ${baseQueryError.message}`);
    }

    // 2) Get risk data separately (handle JSON parsing errors gracefully)
    // Fetch raw result and parse in JavaScript for better error handling
    let riskDataMap = {};
    try {
      const riskResult = await query(
        `
        SELECT DISTINCT ON (ai.student_id)
          ai.student_id,
          ai.result,
          ai.confidence
        FROM ai_insights ai
        WHERE ai.insight_type = 'daily_risk_prediction'
          AND ai.result IS NOT NULL
        ORDER BY ai.student_id, ai.created_at DESC
        `
      );

      riskResult.rows.forEach(row => {
        try {
          // Parse JSON result (stored as TEXT)
          const resultData = typeof row.result === 'string'
            ? JSON.parse(row.result)
            : row.result;

          // Extract risk_level from various possible structures
          const riskLevel = resultData?.risk_level
            || resultData?.ml_prediction?.risk_level
            || resultData?.class_label
            || null;

          // Extract probability from various possible structures
          const probability = resultData?.probability
            || resultData?.ml_prediction?.probability
            || row.confidence
            || null;

          if (riskLevel || probability !== null) {
            riskDataMap[row.student_id] = {
              risk_level: riskLevel,
              probability: probability !== null ? parseFloat(probability) : null
            };
          }
        } catch (parseError) {
          console.warn(`⚠️ [Coordinator Analytics] Failed to parse risk data for student ${row.student_id}:`, parseError.message);
          // Skip this row
        }
      });
      console.log(`✅ [Coordinator Analytics] Loaded risk data for ${Object.keys(riskDataMap).length} students`);
    } catch (riskError) {
      console.warn('⚠️ [Coordinator Analytics] Could not fetch risk data:', riskError.message);
      // Continue without risk data
    }

    console.log(`✅ [Coordinator Analytics] Found ${baseResult.rows.length} active students`);

    if (baseResult.rows.length === 0) {
      console.warn('⚠️ [Coordinator Analytics] No active OJT students found');
    }

    let competencyResult;
    try {
      competencyResult = await query(
        `
        SELECT 
          c.title,
          COALESCE(SUM(t.hours_worked), 0) AS total_hours,
          COUNT(t.task_id)                 AS task_count
        FROM competencies c
        LEFT JOIN task_competencies tc ON c.competency_id = tc.competency_id
        LEFT JOIN ojt_daily_tasks t ON tc.task_id = t.task_id
          AND t.status = 'Approved'
        GROUP BY c.title
        ORDER BY total_hours DESC, c.title
        `
      );
    } catch (compError) {
      console.warn('⚠️ [Coordinator Analytics] Could not fetch competency data:', compError.message);
      competencyResult = { rows: [] };
    }

    const students = baseResult.rows || [];

    // Build per-student analytics
    const perStudent = students.map((row) => {
      const riskInfo = riskDataMap[row.student_id] || {};
      const requiredHours = toNumber(row.required_hours, 300);
      const completedHours = toNumber(row.total_hours_completed, 0);
      const hoursRatio = requiredHours > 0 ? completedHours / requiredHours : 0;

      const attendanceRate = toNumber(row.expected_days, 25) > 0
        ? Math.min((toNumber(row.days_present, 0) / toNumber(row.expected_days, 25)) * 100, 100)
        : 0;

      // Use unified weekly_progress_grade from query
      const weeklyProgressGrade = toNumber(row.weekly_progress_grade, 0);
      const narrativeReportGrade = toNumber(row.narrative_report_grade, 0);
      const coordinatorEvalGrade = toNumber(row.coordinator_eval_grade, 0);
      const supervisorEvalGrade = toNumber(row.supervisor_eval_grade, 0);

      const finalGrade =
        0.2 * weeklyProgressGrade +
        0.2 * narrativeReportGrade +
        0.2 * coordinatorEvalGrade +
        0.4 * supervisorEvalGrade;

      return {
        student_id: row.student_id,
        student_name: row.student_name,
        required_hours: requiredHours,
        total_hours_completed: completedHours,
        hours_completed_ratio: hoursRatio,
        days_present: toNumber(row.days_present, 0),
        late_count: toNumber(row.late_count, 0),
        attendance_rate: attendanceRate,
        total_tasks_logged: toNumber(row.total_tasks_logged, 0),
        total_task_hours: toNumber(row.total_task_hours, 0),
        number_of_distinct_competencies: toNumber(row.number_of_distinct_competencies, 0),
        weekly_progress_grade: weeklyProgressGrade,
        narrative_report_grade: narrativeReportGrade,
        coordinator_eval_grade: coordinatorEvalGrade,
        supervisor_eval_grade: supervisorEvalGrade,
        final_grade: finalGrade,
        risk_level: riskInfo.risk_level || null,
        risk_probability: riskInfo.probability !== null && riskInfo.probability !== undefined
          ? Number(riskInfo.probability)
          : null,
      };
    });

    // Risk summary
    const riskSummary = {
      HIGH: 0,
      MEDIUM: 0,
      LOW: 0,
      UNKNOWN: 0,
    };

    perStudent.forEach((s) => {
      const level = (s.risk_level || 'UNKNOWN').toUpperCase();
      if (riskSummary[level] !== undefined) {
        riskSummary[level] += 1;
      } else {
        riskSummary.UNKNOWN += 1;
      }
    });

    // Attendance summary
    const totalStudents = perStudent.length || 1;
    const avgCompletion =
      perStudent.reduce((sum, s) => sum + (s.hours_completed_ratio || 0), 0) /
      totalStudents;
    const avgAttendanceRate =
      perStudent.reduce((sum, s) => sum + (s.attendance_rate || 0), 0) /
      totalStudents;

    const attendanceSummary = {
      average_completion_ratio: avgCompletion,
      average_attendance_rate: avgAttendanceRate,
    };

    // Evaluation summary
    const evalTotals = perStudent.reduce(
      (acc, s) => {
        acc.wpr += s.weekly_progress_grade || 0;
        acc.nr += s.narrative_report_grade || 0;
        acc.ce += s.coordinator_eval_grade || 0;
        acc.se += s.supervisor_eval_grade || 0;
        acc.final += s.final_grade || 0;
        return acc;
      },
      { wpr: 0, nr: 0, ce: 0, se: 0, final: 0 }
    );

    const evaluationSummary = {
      average_weekly_progress_grade: evalTotals.wpr / totalStudents,
      average_narrative_report_grade: evalTotals.nr / totalStudents,
      average_coordinator_eval_grade: evalTotals.ce / totalStudents,
      average_supervisor_eval_grade: evalTotals.se / totalStudents,
      average_final_grade: evalTotals.final / totalStudents,
    };

    // Competency summary (top 5)
    const competencySummary = (competencyResult.rows || []).map((row) => ({
      title: row.title,
      total_hours: toNumber(row.total_hours, 0),
      task_count: parseInt(row.task_count, 10) || 0,
    }));

    console.log('✅ [Coordinator Analytics] Returning overview with', perStudent.length, 'students');

    return res.json({
      generated_at: new Date().toISOString(),
      per_student: perStudent,
      risk_summary: riskSummary,
      attendance_summary: attendanceSummary,
      evaluation_summary: evaluationSummary,
      competency_summary: competencySummary,
    });
  } catch (error) {
    console.error('❌ Coordinator analytics overview error:', error);
    console.error('Error stack:', error.stack);

    // Try to provide more helpful error message
    let errorMessage = 'Failed to compute coordinator analytics overview';
    if (error.message) {
      errorMessage += `: ${error.message}`;
    }

    return res.status(500).json({
      error: 'Internal server error',
      message: errorMessage,
      details: process.env.NODE_ENV === 'development' ? error.stack : undefined,
    });
  }
});

module.exports = router;


