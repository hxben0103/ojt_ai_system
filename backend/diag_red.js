const { query } = require('./config/db');

async function checkWhyRed() {
  try {
    const ojt = await query("SELECT COUNT(*) FROM ojt_records WHERE status IN ('Ongoing', 'Active')");
    console.log("Active Students Count:", ojt.rows[0].count);

    const insights = await query("SELECT student_id, result->>'risk_level' as risk, result->>'error_type' as err FROM ai_insights ORDER BY created_at DESC LIMIT 5");
    console.log("Recent Insights:", JSON.stringify(insights.rows, null, 2));

    const attendance = await query("SELECT student_id, COUNT(*) as days_present FROM attendance WHERE status IN ('Approved', 'Pending') GROUP BY student_id LIMIT 5");
    console.log("Recent Attendance Data:", JSON.stringify(attendance.rows, null, 2));
    
    process.exit(0);
  } catch(e) {
    console.error("DB Error:", e);
    process.exit(1);
  }
}

checkWhyRed();
