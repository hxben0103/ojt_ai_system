const { Client } = require('pg');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.join(__dirname, 'config', 'env', '.env') });

const client = new Client({
  connectionString: process.env.DATABASE_URL,
});

async function diag() {
  await client.connect();
  const studentId = process.argv[2] || '3';
  
  const res = await client.query(`
    SELECT insight_id, insight_type, result, created_at 
    FROM ai_insights 
    WHERE student_id = $1
    ORDER BY created_at DESC 
    LIMIT 3
  `, [studentId]);

  res.rows.forEach((row, i) => {
    const result = typeof row.result === 'string' ? JSON.parse(row.result) : row.result;
    console.log(`--- Row ${i+1} ---`);
    console.log('ID:', row.insight_id);
    console.log('Type:', row.insight_type);
    console.log('Created:', row.created_at);
    console.log('Gemma Presence Top Level:', !!(result.gemma_explanation || result.summary));
    if (result.ai_prediction) {
       console.log('Gemma Presence Nested:', !!(result.ai_prediction.gemma_explanation || result.ai_prediction.summary));
    }
  });

  await client.end();
}

diag().catch(console.error);
