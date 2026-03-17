const { query } = require('./config/db');

async function checkSchema() {
  try {
    const result = await query(`
      SELECT column_name 
      FROM information_schema.columns 
      WHERE table_name = 'attendance'
    `);
    console.log('Columns:', result.rows.map(r => r.column_name));
  } catch (err) {
    console.error('Error:', err.message);
  } finally {
    process.exit();
  }
}

checkSchema();
