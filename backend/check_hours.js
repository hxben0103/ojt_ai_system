const { Pool } = require('pg');
require('dotenv').config({ path: './config/env/.env' });

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: {
    rejectUnauthorized: false
  }
});

async function checkData() {
  try {
    const res = await pool.query(`
      SELECT 
        attendance_id, student_id, date, total_hours, status, verified
      FROM attendance 
      WHERE total_hours > 0
      ORDER BY created_at DESC 
      LIMIT 10
    `);
    
    console.log(JSON.stringify(res.rows, null, 2));
  } catch (err) {
    console.error('Check failed:', err);
  } finally {
    await pool.end();
  }
}

checkData();
