const { query } = require('./config/db');
const fs = require('fs');

async function readProcedures() {
  try {
    const list = ['generate_batch_predictions', 'generate_performance_prediction', 'calculate_risk_score'];
    
    for (const name of list) {
        console.log(`\n--- PROCEDURE: ${name} ---`);
        const res = await query(`
            SELECT pg_get_functiondef(p.oid) as definition
            FROM pg_proc p
            JOIN pg_namespace n ON p.pronamespace = n.oid
            WHERE n.nspname = 'public' AND p.proname = $1
        `, [name]);
        
        if (res.rows.length > 0) {
            fs.writeFileSync(`proc_${name}.sql`, res.rows[0].definition);
            console.log(`Saved proc_${name}.sql`);
        } else {
            console.log(`Procedure ${name} not found`);
        }
    }
    process.exit(0);
  } catch (error) {
    console.error(error);
    process.exit(1);
  }
}

readProcedures();
