const { query } = require('./config/db');

async function testAttendance() {
  try {
    const student_id = 1004; // Demo student
    const currentDate = new Date().toISOString().split('T')[0];
    const morningIn = '08:00:00';
    const afternoonIn = null;
    
    // First, let's delete existing attendance for this student/date to verify from scratch
    await query('DELETE FROM attendance WHERE student_id = $1 AND date = $2', [student_id, currentDate]);

    console.log("Creating attendance record...");
    const result = await query(
      'SELECT create_attendance($1, $2, $3, NULL, $4, NULL) as result',
      [student_id, currentDate, morningIn, afternoonIn]
    );
    console.log("Create result:", result.rows[0]);

    const select = await query('SELECT * FROM attendance WHERE student_id = $1 AND date = $2', [student_id, currentDate]);
    console.log("DB Row:", select.rows[0]);

  } catch (err) {
    require('fs').writeFileSync('tmp_out16.txt', err.message + "\\n" + err.stack);
  } finally {
    process.exit(0);
  }
}
testAttendance();
