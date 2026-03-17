const { query } = require('./config/db');

async function testBatch() {
  try {
    console.log('Running batch predictions...');
    const res = await query('SELECT * FROM generate_batch_predictions()');
    console.log('Generated:', res.rows.length);
    process.exit(0);
  } catch (error) {
    console.error('--- BATCH FAILED ---');
    console.error('Message:', error.message);
    console.error('Detail:', error.detail);
    console.error('Hint:', error.hint);
    console.error('Where:', error.where);
    console.error('Code:', error.code);
    process.exit(1);
  }
}

testBatch();
