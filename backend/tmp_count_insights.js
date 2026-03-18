const { query } = require('./config/db');

async function check() {
  try {
    const res = await query(`
      SELECT u.full_name, a.insight_type, COUNT(*) as cnt
      FROM ai_insights a
      JOIN users u ON a.student_id = u.user_id
      GROUP BY u.full_name, a.insight_type
      ORDER BY u.full_name, a.insight_type;
    `);
    console.log("Insights count per student:");
    console.table(res.rows);
    
    const studentsRes = await query(`
        SELECT u.user_id, u.full_name, o.status, 
               (SELECT COUNT(*) FROM attendance WHERE student_id = u.user_id AND status='Approved') as approved_attendance,
               (SELECT COUNT(*) FROM ojt_daily_tasks WHERE student_id = u.user_id AND status='Approved') as approved_tasks
        FROM users u
        JOIN ojt_records o ON u.user_id = o.student_id
        WHERE u.role = 'Student' AND o.status IN ('Ongoing', 'Active')
    `);
    console.log("All Active/Ongoing Students data:");
    console.table(studentsRes.rows);
    process.exit(0);
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
}
check();
