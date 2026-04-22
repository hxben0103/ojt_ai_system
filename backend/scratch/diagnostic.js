const { query, pool } = require('../config/db');

async function diagnostic() {
  try {
    const students = await query(`
      SELECT u.user_id, u.full_name, r.start_date, r.end_date, r.required_hours
      FROM users u
      JOIN ojt_records r ON u.user_id = r.student_id
      WHERE u.role = 'Student' AND r.status IN ('Ongoing', 'Active');
    `);

    console.log(`Analyzing ${students.rows.length} active students...\n`);

    for (const s of students.rows) {
      const att = await query("SELECT count(*) as days, sum(total_hours) as hours FROM attendance WHERE student_id = $1 AND status IN ('Approved', 'Pending')", [s.user_id]);
      const tasks = await query("SELECT count(*) as count FROM ojt_daily_tasks WHERE student_id = $1 AND status = 'Approved'", [s.user_id]);
      const evals = await query("SELECT count(*) as count FROM evaluations WHERE student_id = $1", [s.user_id]);

      const daysPresent = parseInt(att.rows[0].days) || 0;
      const totalHours = parseFloat(att.rows[0].hours) || 0;
      const taskCount = parseInt(tasks.rows[0].count) || 0;
      const evalCount = parseInt(evals.rows[0].count) || 0;

      console.log(`[${s.user_id}] ${s.full_name}:`);
      console.log(`   - Hours: ${totalHours} (${daysPresent} days)`);
      console.log(`   - Tasks: ${taskCount}`);
      console.log(`   - Evals: ${evalCount}`);
      console.log(`   - Start: ${s.start_date}, End: ${s.end_date}`);
      
      if (totalHours > 0 && totalHours < 1) {
          console.log(`   ⚠️ WARNING: Very low hours recorded.`);
      }
      if (totalHours > 0 && taskCount === 0) {
          console.log(`   ⚠️ WARNING: Attendance exists but no approved tasks.`);
      }
    }
  } catch (err) {
    console.error(err);
  } finally {
    await pool.end();
  }
}

diagnostic();
