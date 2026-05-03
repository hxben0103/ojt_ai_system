const express = require('express');
const router = express.Router();
const { query } = require('../../config/db');
const axios = require('axios');

// NOTE: Photo storage now uses base64 text in the database (attendance_image column).
// The Supabase Storage bucket upload and multer middleware have been removed.

// Helper: compute verification_status from optional geo/trust (default threshold 60)
function computeVerificationStatus(insideGeofence, trustScore, threshold = 60) {
  if (insideGeofence === false) return 'FLAGGED';
  if (trustScore != null && Number(trustScore) < threshold) return 'FLAGGED';
  return 'AUTO_VERIFIED';
}

function safeFloat(v) {
  if (v == null) return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

// Helper: safe parse int for optional fields
function safeInt(v) {
  if (v == null) return null;
  const n = parseInt(v, 10);
  return Number.isFinite(n) ? n : null;
}
// Helper: format Date object to YYYY-MM-DD string
function formatDate(date) {
  if (!date) return null;
  if (date instanceof Date) {
    // For DATE columns, node-postgres usually returns a Date object at midnight local time.
    // We should extract local parts (not UTC parts) because PHT (UTC+8) shifts midnight to 4PM the previous day in UTC.
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
  }
  if (typeof date === 'string' && date.includes('T')) {
    return date.split('T')[0];
  }
  return date;
}

const authenticateToken = require('../middleware/auth');

// Get all attendance records (optional filter: verification_status=FLAGGED)
router.get('/', authenticateToken, async (req, res) => {
  try {
    const { student_id, date, verification_status } = req.query;

    const { role, user_id } = req.user;
    const params = [];
    let paramCount = 1;

    let sql = `
      SELECT 
        a.attendance_id, a.student_id, a.date, 
        a.morning_in, a.morning_out, a.afternoon_in, a.afternoon_out,
        a.overtime_in, a.overtime_out,
        a.overtime_hours, a.regular_hours, 
        a.total_hours, a.deduction_minutes,
        a.status, a.checkin_lat, a.checkin_lng, a.checkout_lat, a.checkout_lng, 
        a.inside_geofence, a.accuracy_m, a.distance_m,
        a.verification_status, a.trust_score, a.trust_flags,
        a.checkin_photo_path, a.checkout_photo_path, a.photo_url, a.checkout_photo_url,
        (a.attendance_image IS NOT NULL) AS has_base64_image,
        (a.checkout_image IS NOT NULL) AS has_checkout_image,
        a.coordinator_comment, a.coordinator_comment_at,
        u.full_name
      FROM attendance a
      JOIN users u ON a.student_id = u.user_id
      WHERE 1=1
    `;

    // Role-based Data Isolation
    if (role === 'Student') {
      // Students only see their own data
      sql += ` AND a.student_id = $${paramCount}`;
      params.push(user_id);
      paramCount++;
    } else if (role === 'Coordinator') {
      // Coordinators only see students assigned to them
      sql += ` AND EXISTS (
        SELECT 1 FROM ojt_records o 
        WHERE o.student_id = a.student_id 
        AND o.coordinator_id = $${paramCount}
        AND o.status IN ('Active', 'Ongoing')
      )`;
      params.push(user_id);
      paramCount++;
    }

    // Additional filters from query params
    if (student_id) {
      sql += ` AND a.student_id = $${paramCount}`;
      params.push(student_id);
      paramCount++;
    }
    if (date) {
      sql += ` AND a.date = $${paramCount}`;
      params.push(date);
      paramCount++;
    }
    if (verification_status) {
      sql += ` AND a.verification_status = $${paramCount}`;
      params.push(verification_status);
      paramCount++;
    }
    if (req.query.supervisor_id) {
      sql += ` AND EXISTS (
        SELECT 1 FROM ojt_records o 
        WHERE o.student_id = a.student_id 
        AND o.supervisor_id = $${paramCount}
      )`;
      params.push(req.query.supervisor_id);
      paramCount++;
    }

    sql += ' ORDER BY a.date DESC, a.morning_in DESC';

    const result = await query(sql, params);
    
    // Format all dates and add photo flags
    const formattedRows = result.rows.map(row => ({
      ...row,
      date: formatDate(row.date),
      photo_url: row.photo_url || row.checkin_photo_path,
      has_base64_image: !!row.has_base64_image,
      has_checkout_image: !!row.has_checkout_image
    }));
    
    res.json({ attendance: formattedRows });
  } catch (error) {
    console.error('Get attendance error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get specific attendance image (lazy loading)
router.get('/:id/image', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { role, user_id: loggedInUserId } = req.user;

    const sql = `
      SELECT a.attendance_image, a.checkout_image, a.student_id 
      FROM attendance a 
      WHERE a.attendance_id = $1
    `;
    const result = await query(sql, [id]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Attendance record not found' });
    }

    const attendance = result.rows[0];

    // Data Isolation Check
    if (role === 'Coordinator') {
      const accessCheck = await query(
        "SELECT record_id FROM ojt_records WHERE student_id = $1 AND coordinator_id = $2 AND status IN ('Ongoing', 'Active') LIMIT 1",
        [attendance.student_id, loggedInUserId]
      );
      if (accessCheck.rows.length === 0) {
        return res.status(403).json({ error: 'Access Denied', message: 'You can only view images for students assigned to you.' });
      }
    } else if (role === 'Student' && attendance.student_id !== loggedInUserId) {
      return res.status(403).json({ error: 'Access Denied', message: 'You can only view your own attendance images.' });
    }

    res.json({ 
      attendance_image: attendance.attendance_image,
      checkout_image: attendance.checkout_image
    });
  } catch (error) {
    console.error('Get attendance image error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get today's attendance for a student (allows optional date override)
router.get('/today/:studentId', authenticateToken, async (req, res) => {
  try {
    const { studentId } = req.params;
    const { date } = req.query;

    const calculatedDate = date || formatDate(new Date());
    
    console.log(`[Attendance GET /today] Fetching session for student: ${studentId}, date: ${calculatedDate} (input date: ${date || 'none'})`);

    const { role, user_id: loggedInUserId } = req.user;
    
    // Data Isolation: Coordinators can only see their own students
    if (role === 'Coordinator') {
      const accessCheck = await query(
        "SELECT record_id FROM ojt_records WHERE student_id = $1 AND coordinator_id = $2 AND status IN ('Ongoing', 'Active') LIMIT 1",
        [studentId, loggedInUserId]
      );
      if (accessCheck.rows.length === 0) {
        return res.status(403).json({ error: 'Access Denied', message: 'You can only view attendance for students assigned to you.' });
      }
    }

    // Explicit columns — exclude heavy base64 blobs (attendance_image, checkout_image)
    // Those are loaded lazily via GET /:id/image
    const sql = `SELECT a.attendance_id, a.student_id, a.date,
                   a.morning_in, a.morning_out, a.afternoon_in, a.afternoon_out,
                   a.overtime_in, a.overtime_out,
                   a.total_hours, a.regular_hours, a.overtime_hours, a.deduction_minutes,
                   a.verified, a.verified_by, a.verified_at, a.status,
                   a.checkin_lat, a.checkin_lng, a.checkout_lat, a.checkout_lng,
                   a.inside_geofence, a.accuracy_m, a.distance_m,
                   a.verification_status, a.trust_score, a.trust_flags,
                   a.checkin_photo_path, a.checkout_photo_path, a.photo_url, a.checkout_photo_url,
                   (a.attendance_image IS NOT NULL) AS has_base64_image,
                   (a.checkout_image IS NOT NULL) AS has_checkout_image,
                   a.coordinator_comment, a.coordinator_comment_at, a.signature,
                   u.full_name
                 FROM attendance a
                 JOIN users u ON a.student_id = u.user_id
                 WHERE a.student_id = $1 AND a.date = $2`;
    
    const params = [studentId, calculatedDate];

    const result = await query(sql, params);
    
    const attendanceList = result.rows.map(row => ({
      ...row,
      date: formatDate(row.date),
      photo_url: row.photo_url || row.checkin_photo_path,
      has_base64_image: !!row.has_base64_image,
      has_checkout_image: !!row.has_checkout_image
    }));
    
    if (attendanceList.length > 0) {
      res.json({ attendance: attendanceList[0] });
    } else {
      res.json({ attendance: null });
    }
  } catch (error) {
    console.error('Get today attendance error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// NOTE: Duplicate unauthenticated /:id/image route removed.
// The authenticated version above (line 148) is the canonical one.

// NOTE: /upload-photo endpoint removed.
// Photos are now stored as base64 text in the attendance_image column.
// This eliminates the Supabase Storage dependency and the unauthenticated upload vulnerability.

// Create attendance record (Time In) - Using stored procedure
// Supports both legacy time_in and segment-based logging
router.post('/time-in', authenticateToken, async (req, res) => {
  try {
    console.log("📝 [Attendance POST /time-in] Request body:", {
      student_id: req.body.student_id,
      date: req.body.date,
      segment: req.body.segment,
      has_image: !!req.body.attendance_image
    });

    const {
      student_id, attendance_id, segment, date, time_out, attendance_image,
      checkout_lat, checkout_lng, accuracy_m, distance_m, inside_geofence, trust_score, trust_flags,
      checkout_photo_path, checkout_photo_url, checkout_photo_captured_at, verification_status: bodyVerificationStatus,
      checkin_lat, checkin_lng, photo_url, checkin_photo_path, checkin_photo_captured_at // Include all photo fields
    } = req.body;

    if (!student_id) {
      return res.status(400).json({ error: 'student_id is required' });
    }

    // Fetch supervisor_id for auto-verification
    const supervisorCheck = await query(
      `SELECT supervisor_id FROM ojt_records WHERE student_id = $1 AND status IN('Active', 'Ongoing') LIMIT 1`,
      [student_id]
    );
    const supervisorId = supervisorCheck.rows.length > 0 ? supervisorCheck.rows[0].supervisor_id : null;

    const currentDate = date || formatDate(new Date());
    const currentTime = new Date().toTimeString().split(' ')[0].substring(0, 8); // HH:MM:SS format

    // STRICT OJT ENROLLMENT CHECK
    const routeRole = req.user ? req.user.role : 'Student'; 

    if (routeRole === 'Student') {
      const activeOjtCheck = await query(
        `SELECT record_id 
         FROM ojt_records 
         WHERE student_id = $1 
         AND status IN('Active', 'Ongoing')
         AND coordinator_id IS NOT NULL 
         AND supervisor_id IS NOT NULL`,
        [student_id]
      );

      if (activeOjtCheck.rows.length === 0) {
        return res.status(403).json({
          error: 'You cannot perform this action because your OJT setup is incomplete. Coordinator or Supervisor assignment is missing.'
        });
      }
    }

    // HOLIDAY CHECK: Block attendance on university calendar holidays
    // (unless student has approved overtime request for this specific date)
    try {
      const holidayCheck = await query(
        `SELECT title, event_type FROM university_calendar
         WHERE $1::date BETWEEN start_date AND end_date
         AND event_type IN ('holiday')
         LIMIT 1`,
        [currentDate]
      );
      if (holidayCheck.rows.length > 0) {
        // Check if there's an approved overtime request overriding the holiday
        let holidayOverride = false;
        try {
          const otOverride = await query(
            `SELECT request_id FROM supervisor_overtime_requests
             WHERE $1 = ANY(student_ids)
               AND date = $2
               AND status = 'Approved'
             LIMIT 1`,
            [student_id, currentDate]
          );
          holidayOverride = otOverride.rows.length > 0;
        } catch (_) { /* table may not exist yet */ }

        if (!holidayOverride) {
          return res.status(403).json({
            error: `Cannot record attendance on "${holidayCheck.rows[0].title}". This is a university holiday. Contact your supervisor if you need to work on this date.`
          });
        }
        console.log(`[Attendance] Holiday override: approved OT request allows attendance on ${currentDate} (${holidayCheck.rows[0].title})`);
      }
    } catch (holErr) {
      console.warn('[Attendance] Holiday check failed:', holErr.message);
      // Non-fatal: proceed if university_calendar table doesn't exist
    }

    let morningIn = null;
    let afternoonIn = null;
    let overtimeIn = null;

    // Map segment to appropriate field
    if (segment) {
      const normalizedSegment = String(segment).toUpperCase().replace(/\s+/g, '_');
      console.log(`[Attendance POST /time-in] Normalized segment: ${normalizedSegment}`);
      
      switch (normalizedSegment) {
        case 'MORNING_IN':
          morningIn = currentTime;
          break;
        case 'AFTERNOON_IN':
          afternoonIn = currentTime;
          break;
        case 'OVERTIME_IN':
          overtimeIn = currentTime;
          break;
        default:
          return res.status(400).json({ error: 'Invalid or missing segment for time-in' });
      }
    } else {
      return res.status(400).json({ error: 'segment is required' });
    }

    // I2 FIX: Validate overtime approval before allowing OVERTIME_IN
    if (overtimeIn !== null) {
      try {
        const otApprovalCheck = await query(
          `SELECT request_id FROM supervisor_overtime_requests
           WHERE $1 = ANY(student_ids)
             AND date = $2
             AND status = 'Approved'
           LIMIT 1`,
          [student_id, currentDate]
        );
        if (otApprovalCheck.rows.length === 0) {
          return res.status(403).json({
            error: 'Overtime not approved. A supervisor must submit an overtime request and the coordinator must approve it before you can log overtime.'
          });
        }
        console.log(`[Attendance] Overtime approved (request ${otApprovalCheck.rows[0].request_id}) for student ${student_id} on ${currentDate}`);
      } catch (otErr) {
        console.error('[Attendance] Overtime approval check failed:', otErr.message);
        // If the table doesn't exist yet, allow overtime (backward compatible)
      }
    }

    // --- ATOMIC TRANSACTION BLOCK ---
    let attendanceId;
    try {
      // 1. Try to find the record first
      const existingRecord = await query(
        'SELECT attendance_id FROM attendance WHERE student_id = $1 AND date = $2',
        [student_id, currentDate]
      );

      if (existingRecord.rows.length > 0) {
        attendanceId = existingRecord.rows[0].attendance_id;
      } else {
        // 2. Try to create new record
        try {
          const result = await query(
            'SELECT create_attendance($1::integer, $2::date, NULL::time, NULL::time, NULL::time, NULL::time) as result',
            [student_id, currentDate]
          );

          const response = result.rows[0].result;
          if (!response.success) {
             // Check if it's already recorded (race condition handling)
             if (response.errors && response.errors.some(e => e.includes('already recorded'))) {
                const recheck = await query(
                  'SELECT attendance_id FROM attendance WHERE student_id = $1 AND date = $2',
                  [student_id, currentDate]
                );
                if (recheck.rows.length > 0) {
                  attendanceId = recheck.rows[0].attendance_id;
                } else {
                  return res.status(400).json({ error: 'Validation failed', errors: response.errors });
                }
             } else {
               return res.status(400).json({ error: 'Validation failed', errors: response.errors });
             }
          } else {
            attendanceId = response.attendance_id;
          }
        } catch (dbErr) {
          // Handle unique violation error (23505) from race condition
          if (dbErr.code === '23505') {
            const recheck = await query(
              'SELECT attendance_id FROM attendance WHERE student_id = $1 AND date = $2',
              [student_id, currentDate]
            );
            if (recheck.rows.length > 0) {
              attendanceId = recheck.rows[0].attendance_id;
            } else {
              throw dbErr;
            }
          } else {
            throw dbErr;
          }
        }
      }

      // 3. Perform Updates dynamically based on which segment is being logged
      let updateFields = [];
      let updateValues = [];
      let paramCount = 1;

      // Check current state to prevent segment duplicates
      const checkResult = await query(
        'SELECT morning_in, afternoon_in, overtime_in FROM attendance WHERE attendance_id = $1',
        [attendanceId]
      );
      const existingValues = checkResult.rows[0];

      if (morningIn && existingValues.morning_in) {
        return res.status(400).json({ error: 'Time in already recorded for this segment', errors: [`${segment} already exists for this date`] });
      }
      if (afternoonIn && existingValues.afternoon_in) {
        return res.status(400).json({ error: 'Time in already recorded for this segment', errors: [`${segment} already exists for this date`] });
      }
      if (overtimeIn && existingValues.overtime_in) {
        return res.status(400).json({ error: 'Time in already recorded for this segment', errors: [`${segment} already exists for this date`] });
      }

      if (morningIn !== null) {
        updateFields.push(`morning_in = $${paramCount++} `);
        updateValues.push(morningIn);
      }
      if (afternoonIn !== null) {
        updateFields.push(`afternoon_in = $${paramCount++} `);
        updateValues.push(afternoonIn);
      }
      if (overtimeIn !== null) {
        updateFields.push(`overtime_in = $${paramCount++} `);
        updateValues.push(overtimeIn);
      }

      // Store attendance photo as base64 text in DB (no size limit)
      if (attendance_image) {
        updateFields.push(`attendance_image = $${paramCount++} `);
        updateValues.push(attendance_image);
        console.log(`[Attendance] Storing base64 image (${Math.round(String(attendance_image).length/1024)}KB) in DB`);
      }

      // Ensure status is 'Approved' for auto-logging
      updateFields.push(`status = $${paramCount++} `);
      updateValues.push('Approved');
      
      updateFields.push(`verified = $${paramCount++} `);
      updateValues.push(true);

      if (supervisorId) {
        updateFields.push(`verified_by = $${paramCount++} `);
        updateValues.push(supervisorId);
      }

      updateFields.push(`verified_at = CURRENT_TIMESTAMP`);

      updateValues.push(attendanceId);
      await query(
        `UPDATE attendance SET ${updateFields.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE attendance_id = $${paramCount}`,
        updateValues
      );
    } catch (atomicErr) {
      console.error('[Attendance POST /time-in] Transaction error:', atomicErr);
      throw atomicErr;
    }

    // --- BIOMETRIC VERIFICATION (Face Match) ---
    let faceMatchScore = 0;
    let isFaceVerified = false;

    if (attendance_image && String(attendance_image).length > 100) {
      try {
        console.log(`[BIOMETRICS] Starting face verification for student ${student_id}...`);
        
        // 1. Fetch reference photo from registration
        const userRes = await query('SELECT profile_photo FROM users WHERE user_id = $1', [student_id]);
        const profilePhoto = userRes.rows[0]?.profile_photo;

        if (!profilePhoto) {
          console.warn(`[BIOMETRICS] No reference profile photo found for student ${student_id}. Proceeding with warning.`);
        } else {
          // 2. Call AI Module for verification
          const flaskBaseUrl = process.env.FLASK_AI_URL || 'http://localhost:5000';
          const aiRes = await axios.post(`${flaskBaseUrl}/verify-face`, {
            attendance_photo: attendance_image,
            profile_photo: profilePhoto
          }, { timeout: 15000 });

          const aiData = aiRes.data;
          faceMatchScore = aiData.score || 0;
          isFaceVerified = aiData.match || false;

          console.log(`[BIOMETRICS] Match Result: ${isFaceVerified}, Score: ${faceMatchScore}`);

          // 3. STRICT POLICY: Block if mismatch
          if (!isFaceVerified && faceMatchScore < 0.6) {
             console.error(`[BIOMETRICS] REJECTED: Face mismatch for student ${student_id} (Score: ${faceMatchScore})`);
             return res.status(403).json({ 
               success: false, 
               error: 'IDENTITY_VERIFICATION_FAILED',
               message: 'Your face does not match our records. Please ensure your face is clearly visible and matches your registration photo.'
             });
          }
        }
      } catch (biometricErr) {
        console.error('[BIOMETRICS ERROR]', biometricErr.message);
        // Important: If AI server is down, we might want to fail-safe and allow if threshold is met,
        // but for STRICT policy, we might want to log it and proceed or block.
      }
    }

    // Optional geofence/trust/photo/verification: store if columns exist (backward compatible)
    const geoParts = [];
    const geoVals = [];
    let p = 1;
    const clat = safeFloat(checkin_lat); const clng = safeFloat(checkin_lng);
    if (clat != null) { geoParts.push(`checkin_lat = $${p++} `); geoVals.push(clat); }
    if (clng != null) { geoParts.push(`checkin_lng = $${p++} `); geoVals.push(clng); }
    const acc = safeFloat(accuracy_m); const dist = safeFloat(distance_m);
    if (acc != null) { geoParts.push(`accuracy_m = $${p++} `); geoVals.push(acc); }
    if (dist != null) { geoParts.push(`distance_m = $${p++} `); geoVals.push(dist); }
    if (inside_geofence != null) { geoParts.push(`inside_geofence = $${p++} `); geoVals.push(inside_geofence); }
    const tscore = safeInt(trust_score);
    if (tscore != null) { geoParts.push(`trust_score = $${p++} `); geoVals.push(tscore); }
    if (trust_flags != null) {
      const trustFlagsStr = Array.isArray(trust_flags) ? JSON.stringify(trust_flags) : String(trust_flags);
      geoParts.push(`trust_flags = $${p++} `); geoVals.push(trustFlagsStr);
    }
    if (checkin_photo_path != null && String(checkin_photo_path).trim()) {
      geoParts.push(`checkin_photo_path = $${p++} `); geoVals.push(String(checkin_photo_path).trim());
    }
    if (photo_url != null && String(photo_url).trim()) {
      geoParts.push(`photo_url = $${p++} `); geoVals.push(String(photo_url).trim());
    }
    if (checkin_photo_captured_at != null && String(checkin_photo_captured_at).trim()) {
      geoParts.push(`checkin_photo_captured_at = $${p++} `); geoVals.push(String(checkin_photo_captured_at).trim());
    }
    
    // Add face biometric columns
    geoParts.push(`face_match_score = $${p++} `); geoVals.push(faceMatchScore);
    geoParts.push(`is_face_verified = $${p++} `); geoVals.push(isFaceVerified);

    // Finalize verification status (AUTO_APPROVED for clean logs)
    const verStatus = bodyVerificationStatus || computeVerificationStatus(inside_geofence, tscore ?? trust_score, 60);
    const finalVerStatus = verStatus === 'AUTO_VERIFIED' ? 'AUTO_APPROVED' : verStatus;
    geoParts.push(`verification_status = $${p++} `); geoVals.push(finalVerStatus);

    geoVals.push(attendanceId);
    try {
      console.log(`[Attendance POST /time-in] Updating optional columns for ID ${attendanceId}:`, {
        lat: clat, lng: clng, dist, inside: inside_geofence, photo: checkin_photo_path ? 'YES' : 'NO'
      });
      const geoResult = await query(
        `UPDATE attendance SET ${geoParts.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE attendance_id = $${p} RETURNING *`,
        geoVals
      );
      if (geoResult.rows.length > 0) {
        console.log(`[Attendance POST /time-in] Successfully updated geo columns for record ${attendanceId}`);
      } else {
        console.warn(`[Attendance POST /time-in] No rows updated for geo columns for ID ${attendanceId}`);
      }
    } catch (err) {
      console.error('[Attendance POST /time-in] Optional attendance columns update FAILED:', err.message);
    }

    // Get the updated/created attendance record (direct query to return ALL fields the Flutter model needs)
    const attendanceResult = await query(
      `SELECT a.attendance_id, a.student_id, a.date,
              a.morning_in, a.morning_out, a.afternoon_in, a.afternoon_out,
              a.overtime_in, a.overtime_out,
              a.total_hours, a.regular_hours, a.overtime_hours, a.deduction_minutes,
              a.verified, a.verified_by, a.verified_at, a.status,
              a.checkin_lat, a.checkin_lng, a.checkout_lat, a.checkout_lng,
              a.inside_geofence, a.accuracy_m, a.distance_m,
              a.verification_status, a.trust_score, a.trust_flags,
              a.checkin_photo_path, a.checkout_photo_path, a.photo_url, a.checkout_photo_url,
              (a.attendance_image IS NOT NULL) AS has_base64_image,
              (a.checkout_image IS NOT NULL) AS has_checkout_image,
              a.coordinator_comment, a.coordinator_comment_at, a.signature,
              u.full_name
       FROM attendance a
       JOIN users u ON a.student_id = u.user_id
       WHERE a.attendance_id = $1`,
      [attendanceId]
    );

    if (attendanceResult.rows.length === 0) {
      return res.status(404).json({ error: 'Attendance record not found after save' });
    }

    const savedAttendance = {
      ...attendanceResult.rows[0],
      date: formatDate(attendanceResult.rows[0].date),
      has_base64_image: !!attendanceResult.rows[0].has_base64_image,
      has_checkout_image: !!attendanceResult.rows[0].has_checkout_image
    };
    console.log("✅ [Attendance POST /time-in] Attendance saved:", {
      attendance_id: savedAttendance?.attendance_id,
      student_id: savedAttendance?.student_id,
      date: savedAttendance?.date,
      status: savedAttendance?.status || 'Pending',
      time_in: savedAttendance?.morning_in || savedAttendance?.afternoon_in || savedAttendance?.overtime_in
    });
    // Invalidate AI cache to force fresh predictions on dashboard reload
    try {
      await query(
        `DELETE FROM ai_insights WHERE student_id = $1 AND insight_type IN ('daily_risk_prediction', 'performance_prediction')`,
        [student_id]
      );
    } catch (cacheErr) {
      console.error('AI cache invalidation failed:', cacheErr);
    }

    res.status(201).json({
      success: true,
      message: 'Time in recorded successfully',
      attendance: savedAttendance
    });
  } catch (error) {
    console.error('Time in error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update attendance record (Time Out) - Using stored procedure
// Supports both legacy time_out and segment-based logging
router.put('/time-out', authenticateToken, async (req, res) => {
  try {
    console.log("📝 [Attendance PUT /time-out] Request body:", {
      attendance_id: req.body.attendance_id,
      student_id: req.body.student_id,
      date: req.body.date,
      segment: req.body.segment,
      time_out: req.body.time_out
    });

    const { attendance_id, student_id, date, segment, attendance_image,
      checkin_lat, checkin_lng, checkout_lat, checkout_lng, accuracy_m, distance_m, inside_geofence, trust_score, trust_flags,
      checkin_photo_path, checkout_photo_path, checkout_photo_url, checkin_photo_captured_at, checkout_photo_captured_at, verification_status: bodyVerificationStatus } = req.body;

    const currentTime = new Date().toTimeString().split(' ')[0].substring(0, 8); // HH:MM:SS format

    let attendanceId = attendance_id;

    // If attendance_id not provided, try to find by student_id and date
    if (!attendanceId && student_id && date) {
      const findResult = await query(
        'SELECT attendance_id FROM attendance WHERE student_id = $1 AND date = $2',
        [student_id, date]
      );
      if (findResult.rows.length > 0) {
        attendanceId = findResult.rows[0].attendance_id;
      } else {
        return res.status(404).json({ error: 'Attendance record not found for this date' });
      }
    }

    if (!attendanceId) {
      return res.status(400).json({ error: 'attendance_id or (student_id and date) is required' });
    }

    // STRICT OJT ENROLLMENT CHECK
    // Extract student_id from existing attendance record if not provided in body
    let targetStudentId = student_id;
    if (!targetStudentId) {
      const studentIdResult = await query('SELECT student_id FROM attendance WHERE attendance_id = $1', [attendanceId]);
      if (studentIdResult.rows.length > 0) {
        targetStudentId = studentIdResult.rows[0].student_id;
      }
    }

    const routeRole = req.user ? req.user.role : 'Student';
    if (routeRole === 'Student' && targetStudentId) {
      const activeOjtCheck = await query(
        `SELECT record_id 
         FROM ojt_records 
         WHERE student_id = $1 
         AND status IN('Active', 'Ongoing')
         AND coordinator_id IS NOT NULL 
         AND supervisor_id IS NOT NULL`,
        [targetStudentId]
      );

      if (activeOjtCheck.rows.length === 0) {
        return res.status(403).json({
          error: 'You cannot perform this action because your OJT setup is incomplete. Coordinator or Supervisor assignment is missing.'
        });
      }
    }

    // HOLIDAY CHECK: Block time-out on university calendar holidays
    // (unless student has approved overtime request for this specific date)
    const timeOutDate = date || new Date().toISOString().split('T')[0];
    try {
      const holidayCheck = await query(
        `SELECT title, event_type FROM university_calendar
         WHERE $1::date BETWEEN start_date AND end_date
         AND event_type IN ('holiday')
         LIMIT 1`,
        [timeOutDate]
      );
      if (holidayCheck.rows.length > 0) {
        let holidayOverride = false;
        try {
          const otOverride = await query(
            `SELECT request_id FROM supervisor_overtime_requests
             WHERE $1 = ANY(student_ids)
               AND date = $2
               AND status = 'Approved'
             LIMIT 1`,
            [targetStudentId, timeOutDate]
          );
          holidayOverride = otOverride.rows.length > 0;
        } catch (_) { /* table may not exist yet */ }

        if (!holidayOverride) {
          return res.status(403).json({
            error: `Cannot record attendance on "${holidayCheck.rows[0].title}". This is a university holiday.`
          });
        }
        console.log(`[Attendance] Holiday override for time-out: approved OT request on ${timeOutDate}`);
      }
    } catch (holErr) {
      console.warn('[Attendance] Holiday check (time-out) failed:', holErr.message);
    }

    let morningOut = null;
    let afternoonOut = null;
    let overtimeOut = null;
    let timeOutValue = null;

    // Map segment to appropriate field
    if (segment) {
      const normalizedSegment = String(segment).toUpperCase().replace(/\s+/g, '_');
      console.log(`[Attendance PUT /time-out] Normalized segment: ${normalizedSegment}`);
      
      switch (normalizedSegment) {
        case 'MORNING_OUT':
          morningOut = currentTime;
          break;
        case 'AFTERNOON_OUT':
          afternoonOut = currentTime;
          break;
        case 'OVERTIME_OUT':
          overtimeOut = currentTime;
          break;
        default:
          return res.status(400).json({ error: 'Invalid or missing segment for time-out' });
      }
    } else {
      return res.status(400).json({ error: 'segment is required' });
    }

    // Check if this segment is already logged (prevent duplicate)
    const checkRecord = await query(
      'SELECT morning_out, afternoon_out, overtime_out, inside_geofence, trust_score FROM attendance WHERE attendance_id = $1',
      [attendanceId]
    );

    if (checkRecord.rows.length === 0) {
      return res.status(404).json({ error: 'Attendance record not found' });
    }

    const existing = checkRecord.rows[0];

    if ((morningOut && existing.morning_out) ||
      (afternoonOut && existing.afternoon_out) ||
      (overtimeOut && existing.overtime_out)) {
      return res.status(400).json({
        error: 'Time out already recorded for this segment',
        errors: [`${segment} already exists for this record`]
      });
    }

    // Fetch supervisor_id for auto-verification
    const supervisorCheck = await query(
      `SELECT supervisor_id FROM ojt_records WHERE student_id = $1 AND status IN('Active', 'Ongoing') LIMIT 1`,
      [targetStudentId]
    );
    const supervisorId = supervisorCheck.rows.length > 0 ? supervisorCheck.rows[0].supervisor_id : null;

    // Build update query dynamically
    let updateFields = [];
    let updateValues = [];
    let paramCount = 1;

    if (morningOut !== null) {
      updateFields.push(`morning_out = $${paramCount} `);
      updateValues.push(morningOut);
      paramCount++;
    }
    if (afternoonOut !== null) {
      updateFields.push(`afternoon_out = $${paramCount} `);
      updateValues.push(afternoonOut);
      paramCount++;
    }
    if (overtimeOut !== null) {
      updateFields.push(`overtime_out = $${paramCount} `);
      updateValues.push(overtimeOut);
      paramCount++;
    }
    if (updateFields.length === 0) {
      // Allow updating only metadata (photos/geo) without a new timestamp
      console.log("[Attendance PUT /time-out] Meta-only update requested (no new segment logged)");
    }

    // Store checkout photo in separate column (preserves time-in photo in attendance_image)
    if (attendance_image) {
      updateFields.push(`checkout_image = $${paramCount++}`);
      updateValues.push(attendance_image);
      console.log(`[Attendance] Storing checkout base64 image (${Math.round(String(attendance_image).length/1024)}KB) in checkout_image column`);
    }

    // Optional geofence/trust/checkout/photo/verification (time-out)
    const clat = safeFloat(checkin_lat); const clng = safeFloat(checkin_lng);
    if (clat != null) { updateFields.push(`checkin_lat = $${paramCount++}`); updateValues.push(clat); }
    if (clng != null) { updateFields.push(`checkin_lng = $${paramCount++}`); updateValues.push(clng); }
    const outLat = safeFloat(checkout_lat); const outLng = safeFloat(checkout_lng);
    if (outLat != null) { updateFields.push(`checkout_lat = $${paramCount++}`); updateValues.push(outLat); }
    if (outLng != null) { updateFields.push(`checkout_lng = $${paramCount++}`); updateValues.push(outLng); }
    if (accuracy_m != null) { updateFields.push(`accuracy_m = $${paramCount++}`); updateValues.push(safeFloat(accuracy_m)); }
    if (distance_m != null) { updateFields.push(`distance_m = $${paramCount++}`); updateValues.push(safeFloat(distance_m)); }
    if (inside_geofence != null) { updateFields.push(`inside_geofence = $${paramCount++}`); updateValues.push(inside_geofence === true || inside_geofence === 'true'); }
    if (trust_score != null) { updateFields.push(`trust_score = $${paramCount++}`); updateValues.push(Number(trust_score)); }
    if (trust_flags) { updateFields.push(`trust_flags = $${paramCount++}`); updateValues.push(typeof trust_flags === 'string' ? trust_flags : JSON.stringify(trust_flags)); }
    if (checkout_photo_path) { updateFields.push(`checkout_photo_path = $${paramCount++}`); updateValues.push(checkout_photo_path); }
    if (checkout_photo_url) { updateFields.push(`checkout_photo_url = $${paramCount++}`); updateValues.push(checkout_photo_url); }

    // ✅ FIX: Recompute verification status for Time-Out (synchronize with Time-In logic)
    const finalInside = (inside_geofence != null) ? (inside_geofence === true || inside_geofence === 'true') : existing.inside_geofence;
    const finalScore = (trust_score != null) ? Number(trust_score) : existing.trust_score;
    const verStatus = bodyVerificationStatus || computeVerificationStatus(finalInside, finalScore, 60);
    const finalVerStatus = verStatus === 'AUTO_VERIFIED' ? 'AUTO_APPROVED' : (verStatus || existing.verification_status);
    
    updateFields.push(`verification_status = $${paramCount++}`);
    updateValues.push(finalVerStatus);

    updateValues.push(attendanceId);
    const updateSql = `
        UPDATE attendance 
        SET ${updateFields.join(', ')}, updated_at = CURRENT_TIMESTAMP
        WHERE attendance_id = $${paramCount}
        RETURNING *
      `;

    console.log(`[Attendance PUT /time-out] Updating record ${attendanceId} with fields:`, updateFields);
    const updateResult = await query(updateSql, updateValues);
    if (updateResult.rows.length === 0) {
      return res.status(404).json({ error: 'Failed to update attendance record' });
    }

    const attendance = updateResult.rows[0];
    attendance.date = formatDate(attendance.date);
    
    // Add full_name if missing
    if (!attendance.full_name) {
      const userRes = await query('SELECT full_name FROM users WHERE user_id = $1', [attendance.student_id]);
      if (userRes.rows.length > 0) attendance.full_name = userRes.rows[0].full_name;
    }

    // Invalidate AI cache to force fresh predictions on dashboard reload
    try {
      await query(
        `DELETE FROM ai_insights WHERE student_id = $1 AND insight_type IN ('daily_risk_prediction', 'performance_prediction')`,
        [targetStudentId]
      );
    } catch (cacheErr) {
      console.error('AI cache invalidation failed:', cacheErr);
    }

    res.json({ 
      message: 'Time out recorded successfully', 
      attendance 
    });
  } catch (error) {
    console.error('Time out error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});


// Get attendance summary - Using stored procedure
router.get('/summary', authenticateToken, async (req, res) => {
  try {
    const { student_id } = req.query;

    if (student_id) {
      // Use stored procedure for single student
      const result = await query(
        'SELECT get_attendance_statistics($1, NULL, NULL) as statistics',
        [student_id]
      );

      // Get student name separately
      const studentResult = await query(
        'SELECT full_name FROM users WHERE user_id = $1',
        [student_id]
      );

      // Get last duty date
      const lastDutyResult = await query(
        'SELECT MAX(date) as last_duty_date FROM attendance WHERE student_id = $1',
        [student_id]
      );

      const stats = result.rows[0].statistics;
      const studentName = studentResult.rows[0]?.full_name || 'N/A';
      const lastDutyDate = lastDutyResult.rows[0]?.last_duty_date || null;

      res.json({
        summary: [{
          full_name: studentName,
          total_days: parseInt(stats.summary?.total_days || 0),
          total_hours: parseFloat(stats.summary?.total_hours || 0),
          avg_hours_per_day: parseFloat(stats.summary?.avg_hours_per_day || 0),
          last_duty_date: lastDutyDate ? lastDutyDate.toISOString().split('T')[0] : null
        }]
      });
    } else {
      // For multiple students, use view (keep existing logic for compatibility)
      const result = await query(
        'SELECT * FROM view_attendance_summary'
      );
      res.json({ summary: result.rows });
    }
  } catch (error) {
    console.error('Get summary error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get attendance summary by student ID (alternative endpoint)
router.get('/summary/:studentId', authenticateToken, async (req, res) => {
  try {
    const { studentId } = req.params;

    let statsRow = {};
    let studentName = 'N/A';
    let lastDutyDate = null;

    const { role, user_id: loggedInUserId } = req.user;

    // Data Isolation: Check if student belongs to this coordinator
    if (role === 'Coordinator') {
      const accessCheck = await query(
        "SELECT record_id FROM ojt_records WHERE student_id = $1 AND coordinator_id = $2 AND status IN ('Ongoing', 'Active') LIMIT 1",
        [studentId, loggedInUserId]
      );
      if (accessCheck.rows.length === 0) {
        return res.status(403).json({ error: 'Access Denied', message: 'You can only view summary for students assigned to you.' });
      }
    }

    try {
      // Compute summary directly from attendance table, using only APPROVED records.
      const summaryResult = await query(
        `SELECT
  COALESCE(SUM(total_hours), 0)          AS total_hours_completed,
  COALESCE(COUNT(DISTINCT date), 0)      AS total_days_present,
  COALESCE(COUNT(CASE WHEN morning_in IS NOT NULL AND morning_in > '08:00:00' THEN 1 END), 0) AS late_count,
  CASE 
             WHEN COALESCE(COUNT(DISTINCT date), 0) > 0 
               THEN COALESCE(SUM(total_hours), 0) / COALESCE(NULLIF(COUNT(DISTINCT date), 0), 1)
             ELSE 0
           END                                    AS avg_hours_per_day
         FROM attendance
         WHERE student_id = $1 AND status IN ('Approved', 'Pending')`,
        [studentId]
      );

      statsRow = summaryResult.rows[0] || {};

      // CRITICAL: Get last duty date from any attendance
      const lastDutyResult = await query(
        'SELECT MAX(date) as last_duty_date FROM attendance WHERE student_id = $1 AND status IN (\'Approved\', \'Pending\')',
        [studentId]
      );
      lastDutyDate = lastDutyResult.rows[0]?.last_duty_date || null;
    } catch (dbErr) {
      // If the attendance table or columns are missing in the current DB,
      // log the error but still return a safe default summary instead of 500.
      console.error('Attendance summary DB error (using safe defaults):', dbErr);
      statsRow = {};
      lastDutyDate = null;
    }

    try {
      const studentResult = await query(
        'SELECT full_name FROM users WHERE user_id = $1',
        [studentId]
      );
      studentName = studentResult.rows[0]?.full_name || 'N/A';
    } catch (dbErr) {
      console.error('Student lookup error (using default name):', dbErr);
      studentName = 'N/A';
    }

    res.json({
      total_hours_completed: parseFloat(statsRow.total_hours_completed || 0),
      total_days_present: parseInt(statsRow.total_days_present || 0),
      last_duty_date: lastDutyDate ? lastDutyDate.toISOString().split('T')[0] : null,
      avg_hours_per_day: parseFloat(statsRow.avg_hours_per_day || 0),
      student_name: studentName
    });
  } catch (error) {
    console.error('Get summary error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Verify attendance (requires authentication - only Supervisor/Admin can verify)
router.put('/verify/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const supervisorId = req.user.user_id;
    const userRole = req.user.role;

    // Only Supervisor and Admin can verify attendance
    if (userRole !== 'Supervisor' && userRole !== 'Admin') {
      return res.status(403).json({
        error: 'Only supervisors and administrators can verify attendance'
      });
    }

    // Check if attendance record exists
    const checkResult = await query(
      `SELECT a.*, u.full_name as student_name 
       FROM attendance a
       JOIN users u ON a.student_id = u.user_id
       WHERE a.attendance_id = $1`,
      [id]
    );

    if (checkResult.rows.length === 0) {
      return res.status(404).json({ error: 'Attendance record not found' });
    }

    const attendance = checkResult.rows[0];

    // Update attendance with verification info and set status to 'Approved'
    const result = await query(
      `UPDATE attendance 
       SET verified = true,
  status = 'Approved',
  verified_by = $1,
  verified_at = CURRENT_TIMESTAMP
       WHERE attendance_id = $2
RETURNING * `,
      [supervisorId, id]
    );

    // Get updated record with student name
    const updatedResult = await query(
      `SELECT a.*, u.full_name as student_name,
  verifier.full_name as verified_by_name
       FROM attendance a
       JOIN users u ON a.student_id = u.user_id
       LEFT JOIN users verifier ON a.verified_by = verifier.user_id
       WHERE a.attendance_id = $1`,
      [id]
    );

    res.json({
      message: 'Attendance verified successfully',
      attendance: updatedResult.rows[0]
    });
  } catch (error) {
    console.error('Verify attendance error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Approve/Reject attendance (update status)
router.put('/status/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body; // 'Approved' or 'Rejected'
    const supervisorId = req.user.user_id;
    const userRole = req.user.role;

    // Only Supervisor and Admin can approve/reject attendance
    if (userRole !== 'Supervisor' && userRole !== 'Admin') {
      return res.status(403).json({
        error: 'Only supervisors and administrators can approve/reject attendance'
      });
    }

    // Validate status
    if (!['Approved', 'Rejected', 'Pending'].includes(status)) {
      return res.status(400).json({
        error: 'Invalid status. Must be: Approved, Rejected, or Pending'
      });
    }

    // Check if attendance record exists
    const checkResult = await query(
      `SELECT a.*, u.full_name as student_name 
       FROM attendance a
       JOIN users u ON a.student_id = u.user_id
       WHERE a.attendance_id = $1`,
      [id]
    );

    if (checkResult.rows.length === 0) {
      return res.status(404).json({ error: 'Attendance record not found' });
    }

    // Update attendance status
    const updateFields = ['status = $1'];
    const updateValues = [status];
    let paramCount = 2;

    if (status === 'Approved') {
      updateFields.push(`verified = true`);
      updateFields.push(`verified_by = $${paramCount} `);
      updateFields.push(`verified_at = CURRENT_TIMESTAMP`);
      updateValues.push(supervisorId);
      paramCount++;
    } else if (status === 'Rejected') {
      updateFields.push(`verified = false`);
      updateFields.push(`verified_by = NULL`);
      updateFields.push(`verified_at = NULL`);
    } else {
      // Pending
      updateFields.push(`verified = false`);
      updateFields.push(`verified_by = NULL`);
      updateFields.push(`verified_at = NULL`);
    }

    updateValues.push(id);

    const result = await query(
      `UPDATE attendance 
       SET ${updateFields.join(', ')}
       WHERE attendance_id = $${paramCount}
RETURNING * `,
      updateValues
    );

    // Get updated record with student name
    const updatedResult = await query(
      `SELECT a.*, u.full_name as student_name,
  verifier.full_name as verified_by_name
       FROM attendance a
       JOIN users u ON a.student_id = u.user_id
       LEFT JOIN users verifier ON a.verified_by = verifier.user_id
       WHERE a.attendance_id = $1`,
      [id]
    );

    res.json({
      message: `Attendance ${status.toLowerCase()} successfully`,
      attendance: updatedResult.rows[0]
    });
  } catch (error) {
    console.error('Update attendance status error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Unverify attendance (remove verification flag)
router.put('/unverify/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const supervisorId = req.user.user_id;
    const userRole = req.user.role;

    // Only Supervisor and Admin can unverify attendance
    if (userRole !== 'Supervisor' && userRole !== 'Admin') {
      return res.status(403).json({
        error: 'Only supervisors and administrators can unverify attendance'
      });
    }

    const result = await query(
      `UPDATE attendance 
       SET verified = false,
  status = 'Pending',
  verified_by = NULL,
  verified_at = NULL
       WHERE attendance_id = $1
RETURNING * `,
      [id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Attendance record not found' });
    }

    res.json({
      message: 'Attendance verification removed successfully',
      attendance: result.rows[0]
    });
  } catch (error) {
    console.error('Unverify attendance error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Admin Heatmap: Get today's attendance records with GPS for ALL students
router.get('/heatmap', authenticateToken, async (req, res) => {
  try {
    const { role } = req.user;
    if (role !== 'Admin') {
      return res.status(403).json({ error: 'Admin access required' });
    }

    const result = await query(`
      SELECT 
        a.student_id, u.full_name, u.course,
        a.checkin_lat, a.checkin_lng, a.checkout_lat, a.checkout_lng,
        a.morning_in, a.verification_status, a.trust_score, a.inside_geofence,
        o.company_name
      FROM attendance a
      JOIN users u ON a.student_id = u.user_id
      LEFT JOIN ojt_records o ON a.student_id = o.student_id AND o.status IN ('Ongoing', 'Active')
      WHERE a.date = CURRENT_DATE
      ORDER BY a.morning_in DESC
    `);

    res.json({ records: result.rows });
  } catch (error) {
    console.error('Heatmap error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});


// --- SUPERVISOR BATCH OVERTIME REQUESTS (Formal Letter to Coordinator) ---

// 1. Supervisor submits a batch overtime request with formal letter
router.post('/supervisor-overtime-request', authenticateToken, async (req, res) => {
  try {
    const { date, student_ids, formal_letter } = req.body;
    const supervisorId = req.user.user_id;
    const role = req.user.role;

    if (role !== 'Supervisor' && role !== 'Industry Supervisor' && role !== 'Admin') {
      return res.status(403).json({ error: 'Only supervisors can submit overtime requests.' });
    }

    if (!student_ids || !Array.isArray(student_ids) || student_ids.length === 0) {
      return res.status(400).json({ error: 'Please select at least one student.' });
    }
    if (!formal_letter || formal_letter.trim().length === 0) {
      return res.status(400).json({ error: 'A formal letter is required.' });
    }
    if (!date) {
      return res.status(400).json({ error: 'Date is required.' });
    }

    // Find the coordinator for these students (use the first student's coordinator)
    const coordCheck = await query(
      `SELECT DISTINCT coordinator_id FROM ojt_records
       WHERE student_id = ANY($1) AND status IN ('Active','Ongoing') AND coordinator_id IS NOT NULL
       LIMIT 1`,
      [student_ids]
    );
    const coordinatorId = coordCheck.rows.length > 0 ? coordCheck.rows[0].coordinator_id : null;

    const result = await query(
      `INSERT INTO supervisor_overtime_requests (supervisor_id, coordinator_id, date, student_ids, formal_letter, status)
       VALUES ($1, $2, $3, $4, $5, 'Pending')
       RETURNING *`,
      [supervisorId, coordinatorId, date, student_ids, formal_letter.trim()]
    );

    res.json({ success: true, request: result.rows[0] });
  } catch (err) {
    console.error('Submit supervisor overtime request error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// 2. Get overtime requests (role-aware)
router.get('/supervisor-overtime-requests', authenticateToken, async (req, res) => {
  try {
    const userId = req.user.user_id;
    const role = req.user.role;
    let result;

    if (role === 'Student') {
      // Students see requests that include them
      result = await query(
        `SELECT r.*, sup.full_name as supervisor_name
         FROM supervisor_overtime_requests r
         LEFT JOIN users sup ON r.supervisor_id = sup.user_id
         WHERE $1 = ANY(r.student_ids)
         ORDER BY r.date DESC`,
        [userId]
      );
    } else if (role === 'Supervisor' || role === 'Industry Supervisor') {
      result = await query(
        `SELECT r.*, c.full_name as coordinator_name
         FROM supervisor_overtime_requests r
         LEFT JOIN users c ON r.coordinator_id = c.user_id
         WHERE r.supervisor_id = $1
         ORDER BY r.created_at DESC`,
        [userId]
      );
    } else if (role === 'Coordinator' || role === 'Admin') {
      const otParams = role === 'Coordinator' ? [userId] : [];
      const otFilter = role === 'Coordinator' ? 'WHERE r.coordinator_id = $1' : '';
      result = await query(
        `SELECT r.*, sup.full_name as supervisor_name
         FROM supervisor_overtime_requests r
         LEFT JOIN users sup ON r.supervisor_id = sup.user_id
         ${otFilter}
         ORDER BY r.created_at DESC`,
        otParams
      );
    }

    // Resolve student names for each request
    const requests = result ? result.rows : [];
    for (const req_item of requests) {
      // Normalize date to prevent timezone shift (DATE → JS Date → UTC ISO → wrong day)
      if (req_item.date) {
        req_item.date = formatDate(req_item.date);
      }
      if (req_item.student_ids && req_item.student_ids.length > 0) {
        const namesResult = await query(
          `SELECT user_id, full_name FROM users WHERE user_id = ANY($1)`,
          [req_item.student_ids]
        );
        req_item.student_names = namesResult.rows;
      } else {
        req_item.student_names = [];
      }
    }

    res.json({ requests });
  } catch (err) {
    console.error('Get supervisor overtime requests error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// 3. Coordinator approves/rejects a batch overtime request
router.put('/supervisor-overtime-request/:id/status', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { status, coordinator_remarks } = req.body;
    const userId = req.user.user_id;
    const role = req.user.role;

    if (role !== 'Coordinator' && role !== 'Admin') {
      return res.status(403).json({ error: 'Only coordinators can approve overtime requests.' });
    }

    if (!['Approved', 'Rejected'].includes(status)) {
      return res.status(400).json({ error: 'Status must be Approved or Rejected.' });
    }

    const check = await query(`SELECT * FROM supervisor_overtime_requests WHERE request_id = $1`, [id]);
    if (check.rows.length === 0) return res.status(404).json({ error: 'Request not found.' });

    const result = await query(
      `UPDATE supervisor_overtime_requests
       SET status = $1, coordinator_remarks = $2, updated_at = CURRENT_TIMESTAMP
       WHERE request_id = $3 RETURNING *`,
      [status, coordinator_remarks || null, id]
    );

    res.json({ success: true, request: result.rows[0] });
  } catch (err) {
    console.error('Coordinator overtime status update error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;

