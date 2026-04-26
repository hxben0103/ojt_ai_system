const { Pool } = require('pg');
require('dotenv').config({ path: 'c:/Users/ACER/Desktop/OJT _AI_SYSTEM/backend/config/env/.env' });

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function check() {
  try {
    const res = await pool.query('SELECT NOW()');
    console.log('✅ Connection successful:', res.rows[0]);
    
    const users = await pool.query('SELECT count(*) FROM users');
    console.log('✅ Users count:', users.rows[0].count);
  } catch (err) {
    console.error('❌ Connection failed:', err);
  } finally {
    await pool.end();
  }
}

check();
