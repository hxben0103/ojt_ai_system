const { query } = require('./config/db');
const fs = require('fs');

async function dumpInsights() {
  try {
    const students = [
      { id: 'DEMO-STAR-001', name: 'star' },
      { id: 'DEMO-LATE-003', name: 'late' },
      { id: 'DEMO-GHOST-002', name: 'ghost' }
    ];
    
    for (const s of students) {
        const res = await query(`
            SELECT a.result 
            FROM ai_insights a
            JOIN users u ON a.student_id = u.user_id
            WHERE u.student_id = $1
            ORDER BY a.created_at DESC
            LIMIT 1
        `, [s.id]);
        
        if (res.rows.length > 0) {
            fs.writeFileSync(`insight_${s.name}.json`, JSON.stringify(res.rows[0].result, null, 2));
            console.log(`Saved insight_${s.name}.json`);
        } else {
            console.log(`No insight for ${s.name}`);
        }
    }
    process.exit(0);
  } catch (error) {
    console.error(error);
    process.exit(1);
  }
}

dumpInsights();
