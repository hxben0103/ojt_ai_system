const { query } = require('../config/db');
const fs = require('fs');
const path = require('path');

async function updateDatabase() {
  try {
    console.log('Reading stored_procedures_functions.sql...');
    const sqlPath = path.join(__dirname, '../../database/stored_procedures_functions.sql');
    const sql = fs.readFileSync(sqlPath, 'utf8');

    console.log('Clearing old function signatures and dependencies...');
    await query('DROP FUNCTION IF EXISTS get_student_progress(integer) CASCADE;');
    await query('DROP FUNCTION IF EXISTS calculate_risk_score(integer) CASCADE;');
    await query('DROP FUNCTION IF EXISTS generate_performance_prediction(integer) CASCADE;');
    await query('DROP FUNCTION IF EXISTS generate_batch_predictions() CASCADE;');
    await query('DROP FUNCTION IF EXISTS generate_student_progress_report(integer,integer,date,date) CASCADE;');
    await query('DROP FUNCTION IF EXISTS get_student_analytics(integer) CASCADE;');

    console.log('Updating database functions from file...');
    await query(sql);
    
    console.log('✅ Database functions updated successfully!');
  } catch (error) {
    console.error('❌ Failed to update database:', error);
  } finally {
    process.exit();
  }
}

updateDatabase();
