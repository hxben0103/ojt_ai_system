const { Client } = require('pg');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.join(__dirname, 'config', 'env', '.env') });

const client = new Client({
  connectionString: process.env.DATABASE_URL,
});

async function findActiveStudent() {
  await client.connect();
  
  console.log('--- Recently Active Students ---');
  const res = await client.query(`
    SELECT DISTINCT u.user_id, u.full_name, MAX(a.created_at) as last_activity
    FROM users u
    JOIN ai_insights a ON u.user_id = a.student_id
    WHERE u.role = 'student'
    GROUP BY u.user_id, u.full_name
    ORDER BY last_activity DESC
    LIMIT 5
  `);

  console.table(res.rows);

  await client.end();
}

findActiveStudent().catch(console.error);
