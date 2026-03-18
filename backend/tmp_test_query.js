const { query } = require('./config/db');

async function testSnapshot(studentId) {
  try {
    const snapshotResult = await query(`
      WITH 
      ojt_info AS (
        SELECT o.required_hours, o.status, o.start_date, o.end_date, u.full_name AS student_name
        FROM ojt_records o
        JOIN users u ON o.student_id = u.user_id
        WHERE o.student_id = $1 AND o.status IN ('Ongoing', 'Active')
        LIMIT 1
      )
      SELECT 
        (SELECT student_name FROM ojt_info) AS student_name,
        (SELECT COALESCE(required_hours, 300) FROM ojt_info) AS required_hours
    `, [studentId]);
    
    console.log(snapshotResult.rows[0]);
  } catch (err) {
    console.error(err);
  } finally {
    process.exit(0);
  }
}
// 1004 is daryl pogi based on earlier tmp scripts or Demo Student: Star
testSnapshot(1004); // Using arbitrary ID, we'll see if it crashes
