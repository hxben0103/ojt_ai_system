const { Client } = require('pg');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.join(__dirname, 'config', 'env', '.env') });

const client = new Client({
  connectionString: process.env.DATABASE_URL,
});

async function diag() {
  await client.connect();
  console.log('Connected to database');

  const res = await client.query(`
    SELECT insight_id, student_id, result, created_at 
    FROM ai_insights 
    ORDER BY created_at DESC 
    LIMIT 1
  `);

  if (res.rows.length > 0) {
    const row = res.rows[0];
    console.log('--- Latest Insight ---');
    console.log('ID:', row.insight_id);
    console.log('Student ID:', row.student_id);
    console.log('Created At:', row.created_at);
    
    const result = typeof row.result === 'string' ? JSON.parse(row.result) : row.result;
    console.log('Result Keys:', Object.keys(result));
    
    if (result.ai_prediction) {
       console.log('ai_prediction Keys:', Object.keys(result.ai_prediction));
    }
    
    console.log('Gemma Explanation Present:', !!(result.gemma_explanation || result.summary));
    console.log('Summary Content (First 100 chars):', (result.gemma_explanation || result.summary || '').substring(0, 100));
  } else {
    console.log('No insights found');
  }

  await client.end();
}

diag().catch(console.error);
