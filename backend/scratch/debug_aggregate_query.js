const { query } = require('../config/db');

async function testQuery() {
  const generated_by = 4; // Use the coordinator ID from logs
  try {
    const studentsResult = await query(
      `SELECT 
          u.student_id AS school_id,
          u.full_name AS student_name,
          COALESCE(ai.performance, 'N/A') AS performance,
          COALESCE(p.completion_percentage, 0) AS progress
       FROM users u
       JOIN ojt_records o ON u.user_id = o.student_id
       LEFT JOIN LATERAL (
          SELECT result->>'predicted_performance' AS performance
          FROM ai_insights 
          WHERE student_id = u.user_id 
          ORDER BY created_at DESC LIMIT 1
       ) ai ON true
       LEFT JOIN LATERAL (
          SELECT completion_percentage FROM get_student_progress(u.user_id) LIMIT 1
       ) p ON true
       WHERE o.coordinator_id = $1 AND o.status = 'Ongoing'
       ORDER BY u.full_name`,
      [generated_by]
    );
    console.log('Query success! Rows:', studentsResult.rows.length);
    console.log('Sample row:', JSON.stringify(studentsResult.rows[0], null, 2));
  } catch (error) {
    console.error('Query failed!', error);
  } finally {
    process.exit();
  }
}

testQuery();
