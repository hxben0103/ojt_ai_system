const { query } = require('./config/db');

async function debugSpecificStudents() {
  try {
    const students = ['DEMO-STAR-001', 'DEMO-LATE-003', 'DEMO-GHOST-002'];
    
    for (const sid of students) {
        console.log(`\n=== Checking Student: ${sid} ===`);
        const res = await query(`
            SELECT a.*, u.full_name
            FROM ai_insights a
            JOIN users u ON a.student_id = u.user_id
            WHERE u.student_id = $1
            ORDER BY a.created_at DESC
            LIMIT 1
        `, [sid]);
        
        if (res.rows.length === 0) {
            console.log('NO INSIGHTS FOUND');
            // Check if student exists
            const userRes = await query("SELECT user_id, full_name FROM users WHERE student_id = $1", [sid]);
            if (userRes.rows.length > 0) {
                console.log(`User exists: ${userRes.rows[0].full_name} (ID: ${userRes.rows[0].user_id})`);
                // Check if they have attendance/tasks
                const attRes = await query("SELECT COUNT(*) as count, SUM(total_hours) as hours FROM attendance WHERE student_id = $1", [userRes.rows[0].user_id]);
                console.log(`Attendance: ${attRes.rows[0].count} days, ${attRes.rows[0].hours} hours`);
                const taskRes = await query("SELECT COUNT(*) as count FROM ojt_daily_tasks WHERE student_id = $1", [userRes.rows[0].user_id]);
                console.log(`Tasks: ${taskRes.rows[0].count}`);
            } else {
                console.log('USER NOT FOUND');
            }
        } else {
            const r = res.rows[0];
            console.log(`Type: ${r.insight_type}, Confidence: ${r.confidence}`);
            console.log(`Result: ${JSON.stringify(r.result, null, 2)}`);
        }
    }
    
    process.exit(0);
  } catch (error) {
    console.error(error);
    process.exit(1);
  }
}

debugSpecificStudents();
