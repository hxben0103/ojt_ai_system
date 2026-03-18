const { Client } = require('pg');
const dotenv = require('dotenv');
const path = require('path');

// Load environment variables
dotenv.config({ path: path.join(__dirname, 'config', 'env', '.env') });

const client = new Client({
  connectionString: process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/ojt_ai_system'
});

async function diag() {
  try {
    await client.connect();
    console.log('Connected to database');

    const res = await client.query(`
      SELECT a.insight_id, a.student_id, u.full_name, a.insight_type, a.result, a.created_at
      FROM ai_insights a
      JOIN users u ON a.student_id = u.user_id
      ORDER BY a.created_at DESC
      LIMIT 10
    `);

    console.log(`Found ${res.rows.length} recent insights:\n`);

    res.rows.forEach((row, i) => {
      console.log(`--- Insight ${i + 1} ---`);
      console.log(`ID: ${row.insight_id}`);
      console.log(`Student: ${row.full_name} (ID: ${row.student_id})`);
      console.log(`Type: ${row.insight_type}`);
      console.log(`Created At: ${row.created_at}`);
      
      let result = row.result;
      if (typeof result === 'string') {
        try {
          result = JSON.parse(result);
        } catch (e) {
          console.log('Result (non-JSON):', result.substring(0, 500));
        }
      }

      if (typeof result === 'object') {
        processResult(result);
      }
      console.log('\n');
    });

  } catch (err) {
    console.error('Error during diagnostic:', err);
  } finally {
    await client.end();
  }
}

function processResult(result) {
  // Check for common generative fields
  const hasGemmaExplanation = !!result.gemma_explanation;
  const hasSummary = !!result.summary;
  const hasRecommendations = !!result.recommendations || !!result.gemma_recommendations;
  const isEarly = !!result.early_stage;

  console.log(`Fields: gemma_explanation=${hasGemmaExplanation}, summary=${hasSummary}, recommendations=${hasRecommendations}, early_stage=${isEarly}`);
  
  if (hasGemmaExplanation || hasSummary) {
    const text = result.gemma_explanation || result.summary;
    console.log('Narrative Snippet:', text.substring(0, 200) + '...');
  } else {
    console.log('MISSING NARRATIVE!');
  }

  if (result.ml_prediction) {
    console.log('ML Prediction:', JSON.stringify(result.ml_prediction));
  } else if (result.risk_level) {
    console.log('Top-level Risk:', result.risk_level);
  }
}

diag();
