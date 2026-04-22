const { query } = require('../config/db');

async function verify() {
  try {
    const res = await query('SELECT user_id, full_name, role, status, course, program FROM users');
    console.log('--- ALL USERS ---');
    console.log(JSON.stringify(res.rows, null, 2));
  } catch (err) {
    console.error(err);
  } finally {
    process.exit();
  }
}

verify();
