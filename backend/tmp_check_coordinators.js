const { query } = require('./config/db');

async function check() {
  const res = await query(`
    SELECT u.full_name AS student_name, c.full_name AS coordinator_name
    FROM ojt_records o
    JOIN users u ON o.student_id = u.user_id
    LEFT JOIN users c ON o.coordinator_id = c.user_id
    WHERE u.full_name IN ('daryl pogi', 'Demo Student: Star', 'Demo Student: Late')
      AND o.status IN ('Ongoing', 'Active')
  `);
  console.table(res.rows);
  process.exit(0);
}
check();
