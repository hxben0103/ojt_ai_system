const { pool } = require('./config/db');
const { getStudentAIPayload } = require('./api/routes/prediction');

// Since getStudentAIPayload isn't exported, I'll have to mock it or temporarily export it.
// Actually, I can just copy the core logic into a test script to verify the SQL.

async function testSql() {
  const studentId = process.argv[2];
  if (!studentId) {
    console.error('Please provide a student_id');
    process.exit(1);
  }

  try {
    const snapshotResult = await pool.query(`
      WITH 
      ojt_info AS (
        SELECT u.name AS student_name, r.required_hours, r.start_date, r.end_date
        FROM users u 
        JOIN ojt_records r ON u.user_id = r.student_id 
        WHERE u.user_id = $1
      ),
      attendance_stats AS (
        SELECT 
          COALESCE(SUM(a.total_hours), 0) AS total_hours_completed,
          COALESCE(SUM(a.credited_hours), 0) AS credited_hours_completed,
          COALESCE(SUM(CASE WHEN a.late_penalty_applied THEN 2 ELSE 0 END), 0) AS late_penalty_hours,
          COALESCE(COUNT(DISTINCT a.date), 0) AS days_present,
          COALESCE(COUNT(CASE WHEN a.morning_in::time > '08:00:00'::time THEN 1 END), 0) AS late_count
        FROM attendance a
        WHERE a.student_id = $1 AND a.status IN ('Approved', 'Pending')
      ),
      competency_points AS (
        SELECT 
          c.competency_id,
          c.title,
          c.point_value,
          COALESCE(SUM(c.point_value), 0) AS total_points
        FROM competencies c
        LEFT JOIN task_competencies tc ON c.competency_id = tc.competency_id
        LEFT JOIN ojt_daily_tasks t ON tc.task_id = t.task_id 
          AND t.student_id = $1 
          AND t.status = 'Approved'
        GROUP BY c.competency_id, c.title, c.point_value
      )
      SELECT 
        (SELECT student_name FROM ojt_info) AS student_name,
        (SELECT json_agg(json_build_object('title', title, 'points', total_points)) FROM competency_points) AS competency_points_json
    `, [studentId]);

    console.log('Result for student', studentId);
    console.log(JSON.stringify(snapshotResult.rows[0], null, 2));

    const pointsJson = snapshotResult.rows[0].competency_points_json || [];
    pointsJson.forEach(item => {
        const title = item.title;
        const featureName = title.toLowerCase()
                             .replace(/[^a-z0-9]+/g, '_')
                             .replace(/^_+|_+$/g, '');
        console.log(`- ${title} -> ${featureName}: ${item.points} points`);
    });

  } catch (err) {
    console.error(err);
  } finally {
    pool.end();
  }
}

testSql();
