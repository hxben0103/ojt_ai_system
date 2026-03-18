const { query } = require('./config/db');

async function check() {
  const students = ['daryl pogi', 'Demo Student: Star', 'Demo Student: Late'];
  for (const name of students) {
    const res = await query(`
      SELECT a.result
      FROM ai_insights a
      JOIN users u ON a.student_id = u.user_id
      WHERE u.full_name = $1 AND a.insight_type = 'daily_risk_prediction'
      ORDER BY a.created_at DESC
      LIMIT 1
    `, [name]);
    if(res.rows.length) {
        let resObj = typeof res.rows[0].result === 'string' ? JSON.parse(res.rows[0].result) : res.rows[0].result;
        console.log(`--- ${name} ---`);
        console.log(`success:`, resObj.success);
        console.log(`early_stage:`, resObj.early_stage);
        console.log(`ml_prediction risk:`, resObj.ml_prediction?.risk_level);
        console.log(`gemma_explanation length:`, resObj.gemma_explanation?.length);
    }
  }
  process.exit(0);
}
check();
