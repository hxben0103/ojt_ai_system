const { Client } = require('pg');
const dotenv = require('dotenv');
const path = require('path');
const fs = require('fs');

dotenv.config({ path: path.join(__dirname, 'config', 'env', '.env') });

const client = new Client({
  connectionString: process.env.DATABASE_URL,
});

async function diag() {
  await client.connect();
  const studentId = process.argv[2] || '3';
  
  const res = await client.query(`
    SELECT result, insight_type, created_at
    FROM ai_insights 
    WHERE student_id = $1 AND (insight_type = 'daily_risk_prediction' OR insight_type = 'performance_prediction')
    ORDER BY created_at DESC 
    LIMIT 1
  `, [studentId]);

  let output = '--- AI INSIGHT KEYS DIAGNOSTIC ---\n';
  output += `Student ID: ${studentId}\n`;

  if (res.rows.length > 0) {
    const row = res.rows[0];
    const result = typeof row.result === 'string' ? JSON.parse(row.result) : row.result;
    output += `Insight Type: ${row.insight_type}\n`;
    output += `Created At: ${row.created_at}\n\n`;
    output += `Result Keys: ${JSON.stringify(Object.keys(result))}\n`;
    output += `Has gemma_explanation: ${!!result.gemma_explanation}\n`;
    output += `Has gemma_recommendations: ${!!result.gemma_recommendations}\n`;
    output += `Has summary: ${!!result.summary}\n`;
    
    if (result.ai_prediction) {
       output += `\nai_prediction Keys: ${JSON.stringify(Object.keys(result.ai_prediction))}\n`;
       output += `ai_prediction.gemma_explanation: ${!!result.ai_prediction.gemma_explanation}\n`;
       output += `ai_prediction.summary: ${!!result.ai_prediction.summary}\n`;
    }

    if (result.ml_prediction) {
       output += `\nml_prediction Keys: ${JSON.stringify(Object.keys(result.ml_prediction))}\n`;
    }
  } else {
    output += 'No insights found.\n';
  }

  fs.writeFileSync('diag_output.txt', output);
  console.log('Diagnostic written to diag_output.txt');

  await client.end();
}

diag().catch(console.error);
