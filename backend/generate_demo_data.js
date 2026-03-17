const { query } = require('./config/db');
const axios = require('axios');

async function generateDemoData() {
  const coordinatorId = 22; // Mark Jaran Rantilla
  const supervisorId = 6;   // Rico Belga
  
  console.log('--- GENERATING AI DEMO DATA ---');
  console.log(`Coordinator: ${coordinatorId}, Supervisor: ${supervisorId}`);

  try {
    // 0. Cleanup existing demo data (if any)
    console.log('Cleaning up existing demo data...');
    const demoIdsRes = await query("SELECT user_id FROM users WHERE student_id LIKE 'DEMO-%'");
    const demoIds = demoIdsRes.rows.map(r => r.user_id);
    
    if (demoIds.length > 0) {
        await query("DELETE FROM ai_insights WHERE student_id = ANY($1)", [demoIds]);
        await query("DELETE FROM task_competencies WHERE task_id IN (SELECT task_id FROM ojt_daily_tasks WHERE student_id = ANY($1))", [demoIds]);
        await query("DELETE FROM ojt_daily_tasks WHERE student_id = ANY($1)", [demoIds]);
        await query("DELETE FROM attendance WHERE student_id = ANY($1)", [demoIds]);
        await query("DELETE FROM ojt_records WHERE student_id = ANY($1)", [demoIds]);
        await query("DELETE FROM users WHERE user_id = ANY($1)", [demoIds]);
    }

    // 1. Create 3 Demo Students
    const students = [
      { name: 'Demo Student: Star', studentId: 'DEMO-STAR-001', email: 'star@demo.com' },
      { name: 'Demo Student: Ghost', studentId: 'DEMO-GHOST-002', email: 'ghost@demo.com' },
      { name: 'Demo Student: Late', studentId: 'DEMO-LATE-003', email: 'late@demo.com' }
    ];

    const studentIds = [];

    for (const s of students) {
      const res = await query(
        "INSERT INTO users (full_name, student_id, email, password_hash, role) VALUES ($1, $2, $3, 'hashed_password_123', 'Student') RETURNING user_id",
        [s.name, s.studentId, s.email]
      );
      studentIds.push(res.rows[0].user_id);
    }

    const [starId, ghostId, lateId] = studentIds;
    console.log(`Created Students: Star(${starId}), Ghost(${ghostId}), Late(${lateId})`);

    // 2. Create OJT Records
    for (const sid of studentIds) {
      await query(
        "INSERT INTO ojt_records (student_id, coordinator_id, supervisor_id, company_name, status, required_hours, start_date, end_date) VALUES ($1, $2, $3, 'Demo Corp AI Labs', 'Ongoing', 300, CURRENT_DATE - INTERVAL '30 days', CURRENT_DATE + INTERVAL '30 days')",
        [sid, coordinatorId, supervisorId]
      );
    }

    // 3. Generate Attendance (Last 14 Days)
    console.log('Generating Attendance...');
    for (let i = 0; i < 14; i++) {
      const dateStr = `CURRENT_DATE - INTERVAL '${i} days'`;
      
      // Star: Perfect, early attendance
      await query(
        `INSERT INTO attendance (student_id, date, morning_in, morning_out, afternoon_in, afternoon_out, status, total_hours) 
         VALUES ($1, ${dateStr}, '07:55:00', '12:00:00', '13:00:00', '17:00:00', 'Approved', 8)`,
        [starId]
      );

      // Ghost: Only 2 days of attendance (10 days ago and yesterday)
      if (i === 1 || i === 10) {
        await query(
          `INSERT INTO attendance (student_id, date, morning_in, morning_out, afternoon_in, afternoon_out, status, total_hours) 
           VALUES ($1, ${dateStr}, '09:00:00', '12:00:00', '13:00:00', '17:00:00', 'Approved', 7)`,
          [ghostId]
        );
      }

      // Late: Always late
      await query(
        `INSERT INTO attendance (student_id, date, morning_in, morning_out, afternoon_in, afternoon_out, status, total_hours) 
         VALUES ($1, ${dateStr}, '08:45:00', '12:00:00', '13:00:00', '17:00:00', 'Approved', 8)`,
        [lateId]
      );
    }

    // 4. Generate Tasks
    console.log('Generating Tasks...');
    for (let i = 0; i < 15; i++) {
        const res = await query(
            "INSERT INTO ojt_daily_tasks (student_id, task_description, hours_worked, status, date) VALUES ($1, $2, 2, 'Approved', CURRENT_DATE - INTERVAL '1 day') RETURNING task_id",
            [starId, `Diverse Task ${i}`]
        );
        const tid = res.rows[0].task_id;
        await query("INSERT INTO task_competencies (task_id, competency_id) VALUES ($1, $2)", [tid, (i % 5) + 1]);
    }

    for (let i = 0; i < 5; i++) {
        const res = await query(
            "INSERT INTO ojt_daily_tasks (student_id, task_description, hours_worked, status, date) VALUES ($1, $2, 2, 'Approved', CURRENT_DATE - INTERVAL '1 day') RETURNING task_id",
            [lateId, `Repetitive Task ${i}`]
        );
        const tid = res.rows[0].task_id;
        await query("INSERT INTO task_competencies (task_id, competency_id) VALUES ($1, 11)", [tid]); 
    }

    console.log('Triggering AI Batch Prediction...');
    try {
        await axios.post('http://localhost:3000/api/prediction/batch');
        console.log('AI Predictions updated!');
    } catch (apiErr) {
        console.warn('Could not trigger batch prediction via API (is server running?):', apiErr.message);
    }

    console.log('✅ Demo Data Generated Successfully!');
    process.exit(0);

  } catch (err) {
    console.error('❌ Error generating demo data:', err);
    process.exit(1);
  }
}

generateDemoData();
