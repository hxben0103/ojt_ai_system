require('dotenv').config({ path: './config/env/.env' });
const { Pool } = require('pg');

const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: { rejectUnauthorized: false } });

async function main() {
  try {
    const res = await pool.query(`SELECT user_id, full_name, email, role FROM users ORDER BY role, full_name`);
    console.table(res.rows);
  } catch (e) {
    console.error('ERROR:', e.message);
  } finally {
    await pool.end();
  }
}

main();
