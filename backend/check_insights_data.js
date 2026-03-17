const { query } = require('./config/db');

async function checkInsights() {
  try {
    const res = await query(`
      SELECT a.*, u.full_name, u.student_id as school_id
      FROM ai_insights a
      JOIN users u ON a.student_id = u.user_id
      ORDER BY a.created_at DESC
      LIMIT 10
    `);
    
    console.log('--- AI INSIGHTS ---');
    res.rows.forEach(r => {
        console.log(`Student: ${r.full_name} (${r.school_id})`);
        console.log(`Type: ${r.insight_type}, Confidence: ${r.confidence}`);
        console.log(`Result: ${JSON.stringify(r.result, null, 2)}`);
        console.log('-------------------');
    });
    
    process.exit(0);
  } catch (error) {
    console.error(error);
    process.exit(1);
  }
}

checkInsights();
