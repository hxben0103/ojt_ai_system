const { query } = require('./config/db');

async function testFunctions() {
  try {
    const students = ['DEMO-STAR-001', 'DEMO-LATE-003', 'DEMO-GHOST-002'];
    
    for (const sid of students) {
        console.log(`\nTesting ${sid}...`);
        const userRes = await query("SELECT user_id FROM users WHERE student_id = $1", [sid]);
        if (userRes.rows.length === 0) {
            console.log('User not found');
            continue;
        }
        const uid = userRes.rows[0].user_id;
        
        try {
            const res = await query("SELECT generate_performance_prediction($1) as p", [uid]);
            console.log('Result:', JSON.stringify(res.rows[0].p, null, 2));
        } catch (e) {
            console.error('FAILED:', e.message);
        }
    }
    process.exit(0);
  } catch (error) {
    console.error(error);
    process.exit(1);
  }
}

testFunctions();
