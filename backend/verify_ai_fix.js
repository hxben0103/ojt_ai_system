const { query } = require('./config/db');
const axios = require('axios');

async function verifyAll() {
  try {
    const students = [
      { id: 'DEMO-STAR-001', name: 'Star' },
      { id: 'DEMO-LATE-003', name: 'Late' },
      { id: 'DEMO-GHOST-002', name: 'Ghost' }
    ];
    
    console.log('--- RE-RUNNING BATCH PREDICTION ---');
    await query('SELECT * FROM generate_batch_predictions()');
    
    for (const s of students) {
        console.log(`\n=== VERIFYING ${s.name} (${s.id}) ===`);
        
        // 1. Check SQL Insight in DB
        const res = await query(`
            SELECT a.result, a.created_at
            FROM ai_insights a
            JOIN users u ON a.student_id = u.user_id
            WHERE u.student_id = $1
            ORDER BY a.created_at DESC
            LIMIT 1
        `, [s.id]);
        
        if (res.rows.length > 0) {
            const risk = res.rows[0].result.risk_assessment?.risk_level || 'UNKNOWN';
            console.log(`[SQL Result] Risk: ${risk}, Date: ${res.rows[0].created_at}`);
        } else {
            console.log('[SQL Result] NO INSIGHT IN DB');
        }
        
        // 2. Try Daily API (Python)
        console.log(`[Python API] Calling sim_full_fixed logic...`);
        // We'll just run our sim script logic via a child process or similar, but let's just use axios here
        // (Assuming the Flask service is running at 5000)
        const flaskUrl = 'http://localhost:5000/predict';
        // Note: We need a valid payload. We'll reuse the logic from sim_full_fixed.js but simplified.
        
        console.log('Skipping direct python call in this loop to avoid hanging again, will do one separate call');
    }
    
    process.exit(0);
  } catch (error) {
    console.error(error);
    process.exit(1);
  }
}

verifyAll();
