const { query } = require('./config/db');
const axios = require('axios');

async function simulate() {
  try {
    const studentIdString = 'DEMO-STAR-001';
    console.log(`\n--- Simulating for ${studentIdString} ---`);
    
    const userRes = await query("SELECT user_id FROM users WHERE student_id = $1", [studentIdString]);
    const studentId = userRes.rows[0].user_id;

    const snapRes = await query(`
      SELECT 
        (SELECT COALESCE(SUM(total_hours),0) FROM attendance WHERE student_id = $1 AND status = 'Approved') as total_hours,
        (SELECT COUNT(*) FROM ojt_daily_tasks WHERE student_id = $1 AND status = 'Approved') as tasks,
        (SELECT required_hours FROM ojt_records WHERE student_id = $1 LIMIT 1) as required
    `, [studentId]);
    
    const snap = snapRes.rows[0];
    const payload = {
        total_hours_completed: parseFloat(snap.total_hours),
        required_hours: parseFloat(snap.required) || 300,
        total_tasks_logged: parseInt(snap.tasks),
        ojt_status: 'Active'
    };
    
    // Add dummy competencies to match model expectation if needed
    payload.hours_software_development = 0;
    payload.hours_machine_learning_engineering = 0;
    
    console.log('Payload:', JSON.stringify(payload, null, 2));

    const flaskUrl = 'http://localhost:5000';
    const aiRes = await axios.post(`${flaskUrl}/predict`, payload, { timeout: 10000 });
    console.log('AI Response:', JSON.stringify(aiRes.data, null, 2));

    process.exit(0);
  } catch (error) {
    console.error('FAILED:', error.message);
    if (error.response) console.log('Response:', error.response.data);
    process.exit(1);
  }
}

simulate();
