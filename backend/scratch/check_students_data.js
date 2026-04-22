process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
const { query } = require('../config/db');

async function checkStudents() {
  try {
    const res = await query(`
      SELECT role, status, course, program, count(*) 
      FROM users 
      WHERE role = 'Student'
      GROUP BY role, status, course, program
    `);
    console.log('--- STUDENT DATA SUMMARY ---');
    console.table(res.rows);
  } catch (err) {
    console.error('Database Error:', err.message);
  } finally {
    process.exit();
  }
}

checkStudents();
