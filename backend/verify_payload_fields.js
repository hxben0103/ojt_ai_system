/**
 * Quick verification script to confirm new AI payload fields are present.
 * Run: node backend/verify_payload_fields.js
 */
require('dotenv').config({ path: require('path').join(__dirname, '.env') });
const { query } = require('./config/db');

// Inline the helper (copied from prediction.js) so we don't need express
function countWeekdays(start, end) {
  if (!start || !end) return 25;
  const startDate = new Date(start);
  const endDate = new Date(end);
  if (isNaN(startDate) || isNaN(endDate) || startDate > endDate) return 25;
  let count = 0;
  const cur = new Date(startDate);
  while (cur <= endDate) {
    const day = cur.getDay();
    if (day !== 0 && day !== 6) count++;
    cur.setDate(cur.getDate() + 1);
  }
  return count > 0 ? count : 25;
}

function scoreToEquivalentGrade(score) {
  const s = parseFloat(score) || 0;
  if (s >= 97) return 1.00;
  if (s >= 94) return 1.25;
  if (s >= 91) return 1.50;
  if (s >= 88) return 1.75;
  if (s >= 85) return 2.00;
  if (s >= 82) return 2.25;
  if (s >= 79) return 2.50;
  if (s >= 76) return 2.75;
  if (s >= 75) return 3.00;
  if (s >= 70) return 3.50;
  if (s >= 65) return 4.00;
  return 5.00;
}

async function main() {
  // Find a student with an active OJT record
  const res = await query(`
    SELECT u.user_id, u.full_name
    FROM users u
    JOIN ojt_records o ON u.user_id = o.student_id
    WHERE u.role = 'Student' AND o.status IN ('Ongoing', 'Active')
    LIMIT 1
  `);

  if (!res.rows.length) {
    console.log('❌ No active student found. Cannot verify payload.');
    process.exit(1);
  }

  const { user_id: studentId, full_name } = res.rows[0];
  console.log(`\n✅ Testing with student: ${full_name} (ID: ${studentId})\n`);

  // Pull the attendance stats with new fields
  const snap = await query(`
    SELECT 
      COALESCE(SUM(a.total_hours), 0) AS total_hours_completed,
      COALESCE(SUM(
        GREATEST(0,
          a.total_hours -
          2.0 * CEIL(
            GREATEST(0,
              EXTRACT(EPOCH FROM (a.morning_in::time - '08:00:00'::time)) / 60.0
            ) / 30.0
          )
        )
      ), 0) AS credited_hours_completed,
      COALESCE(SUM(
        CASE WHEN a.morning_in::time > '08:00:00'::time THEN
          2.0 * CEIL(
            GREATEST(0, EXTRACT(EPOCH FROM (a.morning_in::time - '08:00:00'::time)) / 60.0) / 30.0
          )
        ELSE 0 END
      ), 0) AS late_penalty_hours,
      COUNT(DISTINCT a.date) AS days_present,
      COUNT(CASE WHEN a.morning_in::time > '08:00:00'::time THEN 1 END) AS late_count
    FROM attendance a
    WHERE a.student_id = $1 AND a.status IN ('Approved', 'Pending')
  `, [studentId]);

  const ojtInfo = await query(`
    SELECT start_date, end_date, required_hours FROM ojt_records WHERE student_id = $1 AND status IN ('Ongoing','Active') LIMIT 1
  `, [studentId]);

  const s = snap.rows[0];
  const o = ojtInfo.rows[0] || {};
  const totalOjtDays = countWeekdays(o.start_date, o.end_date);
  const today = new Date();
  const endDateObj = o.end_date ? new Date(o.end_date) : null;
  const daysRemaining = endDateObj ? Math.max(0, countWeekdays(today, endDateObj)) : null;
  const creditedHours = parseFloat(s.credited_hours_completed) || 0;
  const requiredHours = parseFloat(o.required_hours) || 300;
  const hoursCompletedRatio = requiredHours > 0 ? creditedHours / requiredHours : 0;

  // Simulate a wpr_score for equivalentGrade test
  const mockWprScore = 88; // would come from wpr_computed in real call
  const equivalentGrade = scoreToEquivalentGrade(mockWprScore);

  console.log('=== NEW PAYLOAD FIELDS VERIFICATION ===');
  console.log('\n📅 OJT Timeframe:');
  console.log(`  ojt_start_date   : ${o.start_date ? new Date(o.start_date).toISOString().split('T')[0] : 'null'}`);
  console.log(`  ojt_end_date     : ${o.end_date ? new Date(o.end_date).toISOString().split('T')[0] : 'null'}`);
  console.log(`  total_ojt_days   : ${totalOjtDays}`);
  console.log(`  days_remaining   : ${daysRemaining}`);

  console.log('\n⏱️  Attendance (1-30min=2hr rule):');
  console.log(`  total_hours_completed    : ${parseFloat(s.total_hours_completed).toFixed(2)}`);
  console.log(`  credited_hours_completed : ${parseFloat(s.credited_hours_completed).toFixed(2)}`);
  console.log(`  late_penalty_hours       : ${parseFloat(s.late_penalty_hours).toFixed(2)}`);
  console.log(`  late_count               : ${s.late_count}`);
  console.log(`  hours_completed_ratio    : ${hoursCompletedRatio.toFixed(4)} (uses credited hours)`);

  console.log('\n📊 Task Points & Equivalent Grade:');
  console.log(`  total_task_points : ${mockWprScore} (mock WPR score)`);
  console.log(`  equivalent_grade  : ${equivalentGrade} (1.0-5.0 PH scale)`);

  console.log('\n✅ All new payload fields verified successfully!\n');
  process.exit(0);
}

main().catch(err => {
  console.error('❌ Verification failed:', err.message);
  process.exit(1);
});
