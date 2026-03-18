const { query } = require('./config/db');

async function checkSchema() {
  try {
    console.log('--- ojt_records columns ---');
    const ojtCols = await query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'ojt_records'
    `);
    console.log(ojtCols.rows);

    console.log('--- ai_insights columns ---');
    const cols = await query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'ai_insights'
    `);
    console.log(cols.rows);

    console.log('\n--- users columns ---');
    const usersCols = await query(`
      SELECT column_name, data_type 
      FROM information_schema.columns 
      WHERE table_name = 'users'
    `);
    console.log(usersCols.rows);

    process.exit(0);
  } catch (error) {
    console.error(error);
    process.exit(1);
  }
}

checkSchema();
