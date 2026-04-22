const { query } = require('../config/db');

async function check() {
  try {
    const res = await query(`
      SELECT 
        u.full_name,
        COALESCE(p.completion_percentage, 0) AS progress_percent
      FROM users u
      LEFT JOIN LATERAL (
        SELECT completion_percentage FROM get_student_progress(u.user_id) LIMIT 1
      ) p ON true
      WHERE u.role = 'Student' LIMIT 1
    `);
    console.log('Query succeeded!', res.rows);
  } catch (err) {
    console.log('Query failed:', err.message);
  }
  process.exit();
}
check();
