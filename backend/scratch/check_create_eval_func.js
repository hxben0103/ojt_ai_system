const { query } = require('../config/db');

async function checkFunction() {
  try {
    const res = await query(`
      SELECT pg_get_functiondef(p.oid) as definition
      FROM pg_proc p
      JOIN pg_namespace n ON p.pronamespace = n.oid
      WHERE p.proname = 'create_evaluation'
      AND n.nspname = 'public'
    `);
    
    if (res.rows.length === 0) {
        console.log('Function not found');
    } else {
        console.log(res.rows[0].definition);
    }
    process.exit(0);
  } catch (err) {
    console.error(err);
    process.exit(1);
  }
}

checkFunction();
