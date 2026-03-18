const { query } = require('./config/db');

async function check() {
  const res = await query(`
    SELECT u.full_name, a.result
    FROM (
      SELECT DISTINCT ON (student_id) student_id, result
      FROM ai_insights
      WHERE insight_type = 'daily_risk_prediction'
      ORDER BY student_id, created_at DESC
    ) a
    JOIN users u ON a.student_id = u.user_id
  `);
  res.rows.forEach(r => {
    let resObj = r.result;
    try {
        if (typeof r.result === 'string') {
            resObj = JSON.parse(r.result);
        }
    } catch(e) {}
    console.log(`Student: ${r.full_name}`);
    console.log(`Success: ${resObj?.success}, EarlyStage: ${resObj?.early_stage}, Predict: ${resObj?.ml_prediction != null}`);
    if (resObj && !resObj.success) {
      console.log(`Error: ${resObj.error}`);
    }
    console.log('---');
  });
  process.exit(0);
}
check();
