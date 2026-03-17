const { query } = require('./backend/config/db');

async function checkSchema() {
  try {
    const result = await query(`
      SELECT column_name 
      FROM information_schema.columns 
      WHERE table_name = 'attendance'
      ORDER BY ordinal_position
    `);
    console.log('Columns in attendance table:');
    result.rows.forEach(row => console.log(' - ' + row.column_name));
  } catch (err) {
    console.error('Schema check failed:', err.message);
  } finally {
    process.exit();
  }
}

checkSchema();
