const { query } = require('./config/db');

async function inspectSchema() {
  try {
    console.log('--- AI_INSIGHTS COLUMNS ---');
    const res = await query(`
        SELECT column_name, data_type, udt_name 
        FROM information_schema.columns 
        WHERE table_name = 'ai_insights'
        ORDER BY ordinal_position
    `);
    console.log(JSON.stringify(res.rows, null, 2));
    
    console.log('\n--- CALCULATE_RISK_SCORE PARAMS ---');
    const res2 = await query(`
        SELECT p.proname, p.proargnames, p.proargtypes, p.prorettype, pg_get_function_result(p.oid) as result_type
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.proname = 'calculate_risk_score'
    `);
    console.log(JSON.stringify(res2.rows, null, 2));

    process.exit(0);
  } catch (error) {
    console.error(error);
    process.exit(1);
  }
}

inspectSchema();
