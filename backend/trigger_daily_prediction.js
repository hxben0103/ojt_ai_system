const axios = require('axios');
const { query } = require('./config/db');

async function triggerDaily() {
  try {
    const students = ['DEMO-STAR-001', 'DEMO-LATE-003'];
    
    for (const sid of students) {
        console.log(`\nTriggering daily for ${sid}...`);
        const userRes = await query("SELECT user_id, email FROM users WHERE student_id = $1", [sid]);
        if (userRes.rows.length === 0) {
            console.log(`Student ${sid} not found`);
            continue;
        }
        const userId = userRes.rows[0].user_id;
        
        // We need a token. We'll use the one from the login or just bypass auth if we can edit the route temporarily.
        // Actually, let's just use the /insights POST route which might not be protected or we can call the service logic directly.
        // Better: trigger via a new script that mimics the logic in prediction.js but runs locally.
        
        console.log(`Student ID: ${userId}`);
    }
    process.exit(0);
  } catch (error) {
    console.error(error);
    process.exit(1);
  }
}

triggerDaily();
