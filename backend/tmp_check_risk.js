const { query } = require('./config/db');

async function checkPredictions() {
  try {
    const studentsRes = await query(`
      SELECT 
        u.user_id,
        u.full_name,
        ai.result,
        ai.created_at
      FROM users u
      JOIN ai_insights ai ON u.user_id = ai.student_id
      ORDER BY ai.created_at DESC
      LIMIT 10;
    `);
    
    console.log("Latest AI Predictions for students:");
    for (const row of studentsRes.rows) {
       console.log("-----------------------------------------");
       console.log(`Student: ${row.full_name} (ID: ${row.user_id})`);
       console.log(`Date: ${row.created_at}`);
       console.log(`Insights: `, JSON.stringify(row.result, null, 2));
    }
  } catch (err) {
    require('fs').writeFileSync('tmp_out21.txt', err.message + "\\n" + err.stack);
  } finally {
    process.exit(0);
  }
}
checkPredictions();
