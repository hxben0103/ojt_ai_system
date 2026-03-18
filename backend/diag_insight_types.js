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

  const studentId = process.argv[2] || '3';
  console.log(`Checking all insights for student ${studentId}...`);

  const res = await client.query(`
    SELECT insight_id, insight_type, created_at 
    FROM ai_insights 
    WHERE student_id = $1
    ORDER BY created_at DESC 
    LIMIT 10
  `, [studentId]);

  console.table(res.rows);

  await client.end();
}

diag().catch(console.error);
