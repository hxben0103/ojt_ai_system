const { query } = require('./config/db');

async function debugQuery() {
  try {
    // Mimic Coordinator role with user_id 11 (Mark Jaran)
    const user_id = 11;
    const role = 'Coordinator';
    
    let sql = `
      SELECT o.*,
             s.full_name AS student_name,
             c.full_name AS coordinator_name,
             sup.full_name AS supervisor_name
      FROM ojt_records o
      JOIN users s ON o.student_id = s.user_id
      JOIN users c ON o.coordinator_id = c.user_id
      LEFT JOIN users sup ON o.supervisor_id = sup.user_id
      WHERE 1=1
    `;
    const params = [];
    let paramCount = 1;

    if (role === 'Coordinator') {
      sql += ` AND o.coordinator_id = $${paramCount}`;
      params.push(user_id);
      paramCount++;
    }

    sql += ' ORDER BY o.start_date DESC';

    console.log('Query:', sql);
    console.log('Params:', params);

    const result = await query(sql, params);
    console.log('Result rows:', result.rows.length);
    if (result.rows.length > 0) {
        console.log('First row sample:', result.rows[0]);
    }

    process.exit(0);
  } catch (error) {
    console.error('QUERY FAILED:', error);
    process.exit(1);
  }
}

debugQuery();
