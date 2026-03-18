const { query } = require('./config/db');

async function getDBInfo() {
  try {
    // Check triggers on attendance table
    const triggers = await query(`
      SELECT event_object_table, trigger_name, event_manipulation, action_statement
      FROM information_schema.triggers
      WHERE event_object_table = 'attendance';
    `);
    console.log("--- TRIGGERS on attendance ---");
    console.log(triggers.rows);

    // Check function definition for calculate hours
    const funcs = await query(`
      SELECT routine_name, routine_definition
      FROM information_schema.routines
      WHERE routine_type = 'FUNCTION' 
      AND routine_name ILIKE '%attend%' OR routine_name ILIKE '%hours%';
    `);
    console.log("--- FUNCTIONS ---");
    funcs.rows.forEach(f => {
      console.log(`\n\nFUNCTION: ${f.routine_name}\n${f.routine_definition}`);
    });
  } catch (err) {
    console.error(err);
  } finally {
    process.exit(0);
  }
}
getDBInfo();
