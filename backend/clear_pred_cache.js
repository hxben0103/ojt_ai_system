require('dotenv').config({ path: './config/env/.env' });
const { Pool } = require('pg');
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

pool.query(
  "DELETE FROM ai_insights WHERE insight_type = 'daily_risk_prediction' AND created_at >= NOW() - INTERVAL '4 hours'"
).then(r => {
  console.log('Cleared', r.rowCount, 'cached prediction(s)');
  pool.end();
}).catch(e => {
  console.error('Error:', e.message);
  pool.end();
});
