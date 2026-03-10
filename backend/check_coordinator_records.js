require('dotenv').config({ path: './config/env/.env' });
const { query } = require('./config/db');

async function check() {
    try {
        const res = await query(`
      SELECT o.record_id, o.student_id, o.coordinator_id, o.supervisor_id, o.status,
             s.full_name AS student_name,
             c.full_name AS coordinator_name,
             sup.full_name AS supervisor_name
      FROM ojt_records o
      LEFT JOIN users s ON o.student_id = s.user_id
      LEFT JOIN users c ON o.coordinator_id = c.user_id
      LEFT JOIN users sup ON o.supervisor_id = sup.user_id
    `);
        console.log('All OJT records (LEFT JOIN):', JSON.stringify(res.rows, null, 2));

        const users = await query(`SELECT user_id, email, role, full_name FROM users WHERE role ILIKE '%coordinator%'`);
        console.log('Coordinators:', users.rows);

        const innerJoinRes = await query(`
      SELECT o.record_id, o.student_id, o.coordinator_id, o.supervisor_id, o.status
      FROM ojt_records o
      JOIN users s ON o.student_id = s.user_id
      JOIN users c ON o.coordinator_id = c.user_id
      JOIN users sup ON o.supervisor_id = sup.user_id
    `);
        console.log('INNER JOIN count:', innerJoinRes.rows.length);
    } catch (err) {
        console.error(err);
    }
    process.exit(0);
}

check();
