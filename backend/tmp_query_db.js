const { Pool } = require('pg');
require('dotenv').config({ path: './config/env/.env' });

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: {
    rejectUnauthorized: false
  }
});

async function run() {
  try {
    const res = await pool.query("UPDATE attendance SET date = '2026-03-16' WHERE attendance_id = 111");
    console.log('Update successful:', res.rowCount);
    
    const verify = await pool.query("SELECT attendance_id, date FROM attendance WHERE attendance_id = 111");
    console.log('Verified Record:', verify.rows[0]);
  } catch (err) {
    console.error(err);
  } finally {
    await pool.end();
  }
}

run();
