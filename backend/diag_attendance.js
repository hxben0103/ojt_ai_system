require('dotenv').config({ path: './config/env/.env' });
const { Pool } = require('pg');

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function checkSchema() {
  try {
    const res = await pool.query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'attendance'
    `);
    console.log(res.rows.map(r => `${r.column_name} (${r.data_type})`).join('\n'));
  } catch (e) {
    console.error(e);
  } finally {
    await pool.end();
  }
}

checkSchema();
