const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');
require('dotenv').config({ path: path.join(__dirname, 'config/env/.env') });

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: false,
});

async function runMigration() {
  try {
    const sqlPath = path.join(__dirname, '../database/migration_attendance_rules.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');
    
    console.log('Connecting to Supabase...');
    const client = await pool.connect();
    
    console.log('Running migration script...');
    await client.query(sql);
    
    console.log('✅ Migration successful! deduction_minutes added and rounding trigger updated.');
    client.release();
    process.exit(0);
  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  }
}

runMigration();
