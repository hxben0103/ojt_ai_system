const { query } = require('./backend/config/db');

async function testQuery() {
  try {
    console.log('Testing GET /api/attendance query...');
    const result = await query(`
      SELECT 
        a.attendance_id, a.student_id, a.date, 
        a.morning_in, a.morning_out, a.afternoon_in, a.afternoon_out,
        a.overtime_in, a.overtime_out, a.regular_hours, 
        a.total_hours, a.deduction_minutes,
        a.status, a.checkin_lat, a.checkin_lng, a.checkout_lat, a.checkout_lng, 
        a.verification_status, a.distance_m, a.trust_score, a.trust_flags,
        a.checkin_photo_path, (a.attendance_image IS NOT NULL) AS has_base64_image,
        a.coordinator_comment, a.coordinator_comment_at,
        u.full_name
      FROM attendance a
      JOIN users u ON a.student_id = u.user_id
      LIMIT 1
    `);
    console.log('Query successful! Columns:', Object.keys(result.rows[0]));
  } catch (err) {
    console.error('Query failed:', err.message);
  } finally {
    process.exit();
  }
}

testQuery();
