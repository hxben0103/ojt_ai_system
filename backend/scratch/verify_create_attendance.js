// Quick script to verify the create_attendance function signature in the live DB
const { query } = require('../config/db');

async function main() {
  try {
    // Check which create_attendance overloads exist
    const res = await query(
      `SELECT p.proname, p.pronargs, 
              pg_get_function_arguments(p.oid) as args
       FROM pg_proc p 
       JOIN pg_namespace n ON p.pronamespace = n.oid 
       WHERE p.proname = 'create_attendance' AND n.nspname = 'public'`
    );
    console.log('create_attendance overloads:');
    res.rows.forEach(r => console.log(`  - ${r.proname}(${r.args}) [${r.pronargs} args]`));

    // Also check if time_in column exists
    const colRes = await query(
      `SELECT column_name FROM information_schema.columns 
       WHERE table_name = 'attendance' AND column_name IN ('time_in', 'time_out')
       ORDER BY column_name`
    );
    if (colRes.rows.length === 0) {
      console.log('\n✅ Confirmed: time_in/time_out columns do NOT exist (migration applied)');
    } else {
      console.log('\n⚠️ time_in/time_out columns still exist:', colRes.rows.map(r => r.column_name));
    }

    process.exit(0);
  } catch (e) {
    console.error('Error:', e.message);
    process.exit(1);
  }
}
main();
