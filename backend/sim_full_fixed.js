const { query } = require('./config/db');
const axios = require('axios');

async function simulateFull() {
  try {
    const studentIdString = 'DEMO-STAR-001';
    console.log(`\n--- Simulating FULL for ${studentIdString} ---`);
    
    const userRes = await query("SELECT user_id FROM users WHERE student_id = $1", [studentIdString]);
    const studentId = userRes.rows[0].user_id;

    // Full query logic from prediction.js (FIXED)
    const snapshotResult = await query(`
      WITH 
      ojt_info AS (
        SELECT required_hours, status, start_date, end_date
        FROM ojt_records
        WHERE student_id = $1 AND status IN ('Ongoing', 'Active')
        LIMIT 1
      ),
      attendance_stats AS (
        SELECT 
          COALESCE(SUM(total_hours), 0) AS total_hours_completed,
          COALESCE(COUNT(DISTINCT date), 0) AS days_present,
          COALESCE(COUNT(CASE WHEN morning_in > '08:00:00' THEN 1 END), 0) AS late_count
        FROM attendance
        WHERE student_id = $1 AND status = 'Approved'
      ),
      task_stats AS (
        SELECT 
          COUNT(DISTINCT t.task_id) AS total_tasks_logged,
          COALESCE(SUM(t.hours_worked), 0) AS total_task_hours,
          COUNT(DISTINCT tc.competency_id) AS number_of_distinct_competencies
        FROM ojt_daily_tasks t
        LEFT JOIN task_competencies tc ON t.task_id = tc.task_id
        WHERE t.student_id = $1 AND t.status = 'Approved'
      ),
      integrity_stats AS (
        SELECT inside_geofence, distance_m, accuracy_m, trust_flags, 
               CASE WHEN attendance_image IS NOT NULL THEN true ELSE false END AS has_photo
        FROM attendance
        WHERE student_id = $1 AND date >= CURRENT_DATE - INTERVAL '14 days'
        ORDER BY date DESC, morning_in DESC LIMIT 1
      ),
      recent_flags AS (
        SELECT COUNT(*) AS count FROM attendance
        WHERE student_id = $1 AND date >= CURRENT_DATE - INTERVAL '7 days'
          AND (inside_geofence = false OR trust_flags IS NOT NULL)
      ),
      trend_stats AS (
        SELECT
          COALESCE(SUM(CASE WHEN date >= CURRENT_DATE - INTERVAL '7 days' THEN total_hours ELSE 0 END), 0) AS hours_last_7,
          COALESCE(SUM(CASE WHEN date >= CURRENT_DATE - INTERVAL '14 days' AND date < CURRENT_DATE - INTERVAL '7 days' THEN total_hours ELSE 0 END), 0) AS hours_prev_7
        FROM attendance
        WHERE student_id = $1 AND status = 'Approved'
      )
      SELECT 
        (SELECT required_hours FROM ojt_info) as required_hours,
        (SELECT start_date FROM ojt_info) as ojt_start_date,
        (SELECT end_date FROM ojt_info) as ojt_end_date,
        (SELECT total_hours_completed FROM attendance_stats) as total_hours_completed,
        (SELECT days_present FROM attendance_stats) as days_present,
        (SELECT late_count FROM attendance_stats) as late_count,
        (SELECT total_tasks_logged FROM task_stats) as total_tasks_logged,
        (SELECT total_task_hours FROM task_stats) as total_task_hours,
        (SELECT number_of_distinct_competencies FROM task_stats) as number_of_distinct_competencies,
        (SELECT row_to_json(i) FROM integrity_stats i) as integrity_data,
        (SELECT count FROM recent_flags) as recent_flags_count,
        (SELECT row_to_json(t) FROM trend_stats t) as trend_data
    `, [studentId]);
    
    const snap = snapshotResult.rows[0];
    
    // Helper to count weekdays (simplified)
    const countWeekdays = (s, e) => {
        if (!s || !e) return 25;
        let count = 0; let cur = new Date(s); let end = new Date(e);
        while (cur <= end) {
            let d = cur.getDay(); if (d!=0 && d!=6) count++;
            cur.setDate(cur.getDate()+1);
        }
        return count || 25;
    };

    const daysPresent = parseFloat(snap.days_present) || 0;
    const requiredDays = countWeekdays(snap.ojt_start_date, snap.ojt_end_date);
    const attendanceRate = requiredDays > 0 ? (daysPresent / requiredDays) * 100 : 0;
    const totalHours = parseFloat(snap.total_hours_completed) || 0;
    const reqHours = parseFloat(snap.required_hours) || 300;

    const payload = {
        total_hours_completed: totalHours,
        required_hours: reqHours,
        attendance_rate: attendanceRate,
        late_count: parseInt(snap.late_count) || 0,
        absent_count: Math.max(0, requiredDays - daysPresent),
        hours_completed_ratio: totalHours / reqHours,
        ojt_status: 'Active',
        total_tasks_logged: parseInt(snap.total_tasks_logged) || 0,
        total_task_hours: parseFloat(snap.total_task_hours) || 0,
        number_of_distinct_competencies: parseInt(snap.number_of_distinct_competencies) || 0,
        
        // Competencies (Hardcoded for now as placeholders)
        hours_software_development: 0,
        hours_machine_learning_engineering: 0,
        hours_it_related_research: 0,
        hours_ux_ui_design: 0,
        hours_information_security_analysis: 0,
        hours_networking: 0,
        hours_technical_support: 0,
        hours_data_analysis: 0,
        hours_customer_service: 0,
        hours_data_entry_management: 0,
        hours_office_work: 0,

        // Grades
        weekly_progress_grade: 0,
        narrative_report_grade: 0,
        coordinator_eval_grade: 0,
        supervisor_eval_grade: 0,
        has_weekly_progress_grade: 0,
        has_narrative_report_grade: 0,
        has_coordinator_eval_grade: 0,
        has_supervisor_eval_grade: 0,

        // Integrity
        inside_geofence: snap.integrity_data?.inside_geofence !== false,
        distance_m: parseFloat(snap.integrity_data?.distance_m) || 0.0,
        accuracy_m: parseFloat(snap.integrity_data?.accuracy_m) || 10.0,
        trust_flags: snap.integrity_data?.trust_flags || "",
        has_photo: snap.integrity_data?.has_photo !== false,
        recent_flags_count: parseInt(snap.recent_flags_count) || 0,
        
        // Chatbot
        total_chatbot_queries: 0,
        chatbot_queries_last_30_days: 0
    };
    
    console.log('Payload:', JSON.stringify(payload, null, 2));

    const flaskUrl = 'http://localhost:5000';
    try {
        const aiRes = await axios.post(`${flaskUrl}/predict`, payload, { timeout: 30000 });
        console.log('AI Response:', JSON.stringify(aiRes.data, null, 2));
    } catch (e) {
        console.error('FLASK FAILED:', e.message);
        if (e.response) console.log('Data:', e.response.data);
    }

    process.exit(0);
  } catch (error) {
    console.error('SYSTEM ERROR:', error);
    process.exit(1);
  }
}

simulateFull();
