const { query } = require('./config/db');

async function fixFuncs() {
  try {
    console.log("Dropping ambiguous function...");
    
    // Drop the 8-parameter version that conflicts with the 6 parameter one when using defaults
    await query(`
      DROP FUNCTION IF EXISTS create_attendance(
        integer, date, time without time zone, time without time zone, 
        time without time zone, time without time zone, time without time zone, time without time zone
      );
    `);
    
    console.log("Success! Old function dropped.");
  } catch (err) {
    console.error("Database Error:", err.message);
  } finally {
    process.exit(0);
  }
}

fixFuncs();
