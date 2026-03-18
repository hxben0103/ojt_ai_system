const { query } = require('./config/db');

async function testDate() {
  try {
    const result = await query(`SELECT '2026-03-18'::date as test_date`);
    const date = result.rows[0].test_date;
    console.log("Raw date output:", date);
    console.log("Type:", typeof date);
    console.log("Is Date instance:", date instanceof Date);
    
    if (date instanceof Date) {
      console.log("getUTCDate():", date.getUTCDate());
      console.log("getDate() (Local):", date.getDate());
      console.log("Current formatDate behavior:", `${date.getUTCFullYear()}-${String(date.getUTCMonth() + 1).padStart(2, '0')}-${String(date.getUTCDate()).padStart(2, '0')}`);
      console.log("Expected local behavior:", `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`);
    }
  } catch (err) {
    console.error(err);
  } finally {
    process.exit(0);
  }
}
testDate();
