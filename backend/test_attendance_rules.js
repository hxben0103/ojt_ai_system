const path = require('path');
const { Pool } = require('pg');
require('dotenv').config({ path: path.join(__dirname, 'config/env/.env') });

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: false,
});

async function runTests() {
  const client = await pool.connect();
  
  try {
    const userRes = await client.query("SELECT user_id FROM users WHERE role = 'Student' LIMIT 1");
    if (userRes.rows.length === 0) throw new Error("No student found");
    const stdId = userRes.rows[0].user_id;

    await client.query("DELETE FROM attendance WHERE date IN ('2023-01-01', '2023-01-02', '2023-01-03', '2023-01-04', '2023-01-05', '2023-01-06')");

    const tests = [
      {
        name: "Example 1: On-time (Exactly 8 hours)",
        q: `INSERT INTO attendance (student_id, date, morning_in, morning_out, afternoon_in, afternoon_out) VALUES (${stdId}, '2023-01-02', '08:00:00', '12:00:00', '13:00:00', '17:00:00') RETURNING total_hours, deduction_minutes`
      },
      {
        name: "Example 2: Arrive 2 minutes late (Deduct 30 mins, 7.5 hours credited)",
        q: `INSERT INTO attendance (student_id, date, morning_in, morning_out, afternoon_in, afternoon_out) VALUES (${stdId}, '2023-01-03', '08:02:00', '12:00:00', '13:00:00', '17:00:00') RETURNING total_hours, deduction_minutes`
      },
      {
        name: "Example 3: Arrive 31 minutes late (Deduct 60 mins, 7.0 hours credited)",
        q: `INSERT INTO attendance (student_id, date, morning_in, morning_out, afternoon_in, afternoon_out) VALUES (${stdId}, '2023-01-04', '08:31:00', '12:00:00', '13:00:00', '17:00:00') RETURNING total_hours, deduction_minutes`
      },
      {
        name: "Example 4: Early Arrival / Late Departure (Strict 8 Hour Cap)",
        q: `INSERT INTO attendance (student_id, date, morning_in, morning_out, afternoon_in, afternoon_out) VALUES (${stdId}, '2023-01-05', '07:30:00', '12:30:00', '12:50:00', '18:00:00') RETURNING total_hours, deduction_minutes`
      },
      {
        name: "Example 5: Weekend Override (Defaults to 0 on Sunday '2023-01-01')",
        q: `INSERT INTO attendance (student_id, date, morning_in, morning_out, afternoon_in, afternoon_out) VALUES (${stdId}, '2023-01-01', '08:00:00', '12:00:00', '13:00:00', '17:00:00') RETURNING total_hours, deduction_minutes, EXTRACT(DOW FROM date) as day_of_week`
      }
    ];

    for (let test of tests) {
      const res = await client.query(test.q);
      console.log(`\n--- Test: ${test.name} ---`);
      console.log(`Expected Total Hours / Deduction depend on rule. Actual Result:`);
      console.dir(res.rows[0]);
    }

  } catch (err) {
    console.error('ERROR:', err);
  } finally {
    client.release();
    process.exit(0);
  }
}

runTests().catch(console.error);
