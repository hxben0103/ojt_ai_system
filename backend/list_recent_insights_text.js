const { Client } = require('pg');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.join(__dirname, 'config', 'env', '.env') });

const client = new Client({
  connectionString: process.env.DATABASE_URL,
});

async function findActiveStudent() {
  await client.connect();
  
  const res = await client.query(`
    SELECT student_id, insight_type, created_at
    FROM ai_insights
    ORDER BY created_at DESC
    LIMIT 10
  `);

  res.rows.forEach(row => {
    console.log(`Student: ${row.student_id} | Type: ${row.insight_type} | Date: ${row.created_at}`);
  });

  await client.end();
}

findActiveStudent().catch(console.error);
