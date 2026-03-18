const { query } = require('./config/db');

async function checkFunc() {
  try {
    const res = await query(`
      SELECT pg_get_function_arguments(oid) as args
      FROM pg_proc 
      WHERE proname = 'create_attendance'
    `);
    console.log(res.rows);
  } catch (err) {
    console.error(err);
  } finally {
    process.exit(0);
  }
}
checkFunc();
