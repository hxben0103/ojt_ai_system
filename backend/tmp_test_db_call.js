const { query } = require('./config/db');

async function testQuery() {
  try {
    const student_id = 3;
    const currentDate = new Date('2026-03-18');
    const morningIn = '08:00:00';
    const afternoonIn = null;
    
    // Testing the EXACT syntax used in attendance.js
    const sql = 'SELECT create_attendance($1::integer, $2::date, $3::time, NULL::time, $4::time, NULL::time) as result';
    
    console.log("Running SQL: ", sql);
    const result = await query(sql, [student_id, currentDate, morningIn, afternoonIn]);
    console.log("Result:", result.rows[0]);
  } catch (err) {
    console.error("Database Error:", err.message);
  } finally {
    process.exit(0);
  }
}

testQuery();
