const { query } = require('./config/db');
const axios = require('axios');

async function simulateDaily(studentIdString) {
  try {
    console.log(`Simulating daily for ${studentIdString}...`);
    const userRes = await query("SELECT user_id FROM users WHERE student_id = $1", [studentIdString]);
    if (userRes.rows.length === 0) {
        console.log('User not found');
        return;
    }
    const studentId = userRes.rows[0].user_id;

    // --- COPIED LOGIC FROM prediction.js ---
    // (Abridged for brevity but core payload logic)
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
      )
      SELECT 
        (SELECT required_hours FROM ojt_info) as required_hours,
        (SELECT total_hours_completed FROM attendance_stats) as total_hours_completed,
        (SELECT days_present FROM attendance_stats) as days_present,
        (SELECT late_count FROM attendance_stats) as late_count,
        (SELECT total_tasks_logged FROM task_stats) as total_tasks_logged,
        (SELECT json_agg(json_build_object('title', c.title, 'hours', COALESCE(SUM(t.hours_worked), 0))) 
         FROM competencies c 
         LEFT JOIN task_competencies tc ON c.competency_id = tc.competency_id 
         LEFT JOIN ojt_daily_tasks t ON tc.task_id = t.task_id AND t.student_id = $1 AND t.status = 'Approved'
         GROUP BY c.title) as competencies
    `, [studentId]);

    const snap = snapshotResult.rows[0];
    const payload = {
        total_hours_completed: parseFloat(snap.total_hours_completed),
        required_hours: parseFloat(snap.required_hours) || 300,
        late_count: parseInt(snap.late_count),
        total_tasks_logged: parseInt(snap.total_tasks_logged),
        ojt_status: 'Active'
    };
    
    // Add competencies
    if (snap.competencies) {
        snap.competencies.forEach(c => {
            const key = 'hours_' + (c.title || '').toLowerCase().replace(/\s+/g, '_').replace(/[^a-z0-9_]/g, '');
            payload[key] = parseFloat(c.hours) || 0;
        });
    }

    console.log('--- PAYLOAD ---');
    console.log(JSON.stringify(payload, null, 2));

    const flaskUrl = 'http://localhost:5000';
    console.log(`Calling Flask AI at ${flaskUrl}/predict...`);
    
    try {
        const aiRes = await axios.post(`${flaskUrl}/predict`, payload, { timeout: 10000 });
        console.log('--- AI RESPONSE ---');
        console.log(JSON.stringify(aiRes.data, null, 2));
    } catch (e) {
        console.error('FLASK ERROR:', e.message);
        if (e.response) {
            console.error('Response Status:', e.response.status);
            console.error('Response Data:', JSON.stringify(e.response.data, null, 2));
        }
    }

    process.exit(0);
  } catch (error) {
    console.error(error);
    process.exit(1);
  }
}

simulateDaily(process.argv[2] || 'DEMO-STAR-001');
