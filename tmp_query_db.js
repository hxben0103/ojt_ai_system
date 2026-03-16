const { Pool } = require('pg');
require('dotenv').config({ path: 'c:/Users/ACER/Desktop/OJT _AI_SYSTEM/backend/config/env/.env' });

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: {
    rejectUnauthorized: false
  }
});

async function run() {
  try {
    const res = await pool.query('SELECT attendance_id, date, time_in, time_out, morning_in, morning_out, afternoon_in, afternoon_out, status FROM attendance WHERE student_id = 23 ORDER BY date DESC LIMIT 5');
    console.log(JSON.stringify(res.rows, null, 2));
  } catch (err) {
    console.error(err);
  } finally {
    await pool.end();
  }
}

run();
