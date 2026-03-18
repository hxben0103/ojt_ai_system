const { query } = require('./config/db');

async function viewAttendance() {
  try {
    const result = await query(`
      SELECT attendance_id, student_id, date, 
             morning_in, morning_out, afternoon_in, afternoon_out,
             overtime_in, overtime_out,
             regular_hours, overtime_hours, total_hours
      FROM attendance
      WHERE date >= CURRENT_DATE - INTERVAL '2 days'
      ORDER BY date DESC, created_at DESC
      LIMIT 10;
    `);
    console.table(result.rows);
  } catch (err) {
    console.error(err);
  } finally {
    process.exit(0);
  }
}
viewAttendance();
