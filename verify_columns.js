const { Pool } = require('pg');
require('dotenv').config({ path: './config/env/.env' });

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function verify() {
  try {
    const res = await pool.query(`
      SELECT column_name 
      FROM information_schema.columns 
      WHERE table_name = 'attendance' AND column_name IN ('coordinator_comment', 'coordinator_comment_at');
    `);
    
    console.log('Columns found in attendance table:');
    res.rows.forEach(row => console.log(`- ${row.column_name}`));
    
    if (res.rows.length === 2) {
      console.log('SUCCESS: Both coordinator_comment columns exist.');
    } else {
      console.log('FAILURE: Missing columns.');
    }
  } catch (err) {
    console.error('Check failed:', err);
  } finally {
    await pool.end();
  }
}

verify();
