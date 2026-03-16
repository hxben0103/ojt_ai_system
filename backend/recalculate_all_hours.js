const { Pool } = require('pg');
require('dotenv').config({ path: './config/env/.env' });

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: {
    rejectUnauthorized: false
  }
});

async function migrate() {
  try {
    console.log('Recalculating all attendance hours...');
    
    // We can simply run an UPDATE on all rows that have both in/out for any segment
    // This will trigger the calculate_attendance_hours() function for each row
    const res = await pool.query(`
      UPDATE attendance 
      SET updated_at = CURRENT_TIMESTAMP
      WHERE 
        (morning_in IS NOT NULL AND morning_out IS NOT NULL) OR
        (afternoon_in IS NOT NULL AND afternoon_out IS NOT NULL) OR
        (overtime_in IS NOT NULL AND overtime_out IS NOT NULL)
      RETURNING attendance_id
    `);
    
    console.log(`Successfully updated ${res.rowCount} records.`);
  } catch (err) {
    console.error('Migration failed:', err);
  } finally {
    await pool.end();
  }
}

migrate();
