const { query } = require('./config/db');
const fs = require('fs');
const path = require('path');

async function applyIndexes() {
  try {
    console.log('Reading migration file...');
    const sql = fs.readFileSync(path.join(__dirname, '../database/add_performance_indexes.sql'), 'utf8');
    
    console.log('Applying indexes to database...');
    // Split by semicolons and execute each
    const statements = sql.split(';').filter(s => s.trim().length > 0);
    
    for (const stmt of statements) {
      console.log(`Executing: ${stmt.trim().substring(0, 50)}...`);
      await query(stmt);
    }
    
    console.log('✅ Performance indexes applied successfully!');
    process.exit(0);
  } catch (err) {
    console.error('❌ Error applying indexes:', err);
    process.exit(1);
  }
}

applyIndexes();
