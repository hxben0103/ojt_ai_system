const express = require('express');
const router = express.Router();
const path = require('path');
const multer = require('multer');
const { query } = require('../../config/db');
const { uploadAttendancePhoto } = require('../../config/supabaseClient');
const jwt = require('jsonwebtoken');

// Photo upload: use memory storage (no local disk writes)
const uploadPhoto = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 },
}).single('photo');

// Helper: compute verification_status from optional geo/trust (default threshold 60)
function computeVerificationStatus(insideGeofence, trustScore, threshold = 60) {
  if (insideGeofence === false) return 'FLAGGED';
  if (trustScore != null && Number(trustScore) < threshold) return 'FLAGGED';
  return 'AUTO_VERIFIED';
}

// Helper: safe parse float/int for optional fields
function safeFloat(v) {
  if (v == null) return null;
  const n = Number(v);
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

// Authentication middleware
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  jwt.verify(token, process.env.JWT_SECRET || 'your_secret_key', (err, user) => {
    if (err) {
      return res.status(403).json({ error: 'Invalid or expired token' });
    }
    req.user = user;
    next();
  });
};

// Get all attendance records (optional filter: verification_status=FLAGGED)
router.get('/', authenticateToken, async (req, res) => {
  try {
    const { student_id, date, verification_status } = req.query;

    let sql = `
      SELECT 
        a.attendance_id, a.student_id, a.date, 
        a.morning_in, a.morning_out, a.afternoon_in, a.afternoon_out,
        a.overtime_hours, a.regular_hours, 
        a.total_hours, a.deduction_minutes,
        a.status, a.checkin_lat, a.checkin_lng, a.checkout_lat, a.checkout_lng, 
        a.verification_status, a.distance_m, a.trust_score, a.trust_flags,
        a.checkin_photo_path, (a.attendance_image IS NOT NULL) AS has_base64_image,
        a.coordinator_comment, a.coordinator_comment_at,
        u.full_name
      FROM attendance a
      JOIN users u ON a.student_id = u.user_id
      -- Join OJT records to check coordinator
      LEFT JOIN ojt_records o ON a.student_id = o.student_id AND o.status IN ('Ongoing', 'Active')
      WHERE 1=1
    `;
    const params = [];
    const { role, user_id } = req.user;
    let paramCount = 1;

    // Data Isolation: Coordinators can only see their own students' attendance
    if (role === 'Coordinator') {
      sql += ` AND o.coordinator_id = $${paramCount}`;
      params.push(user_id);
      paramCount++;
    }

    if (student_id) {
      sql += ` AND a.student_id = $${paramCount} `;
      params.push(student_id);
      paramCount++;
    }
    if (date) {
      sql += ` AND a.date = $${paramCount} `;
      params.push(date);
      paramCount++;
    }
    if (verification_status) {
      sql += ` AND a.verification_status = $${paramCount} `;
      params.push(verification_status);
      paramCount++;
    }

    sql += ' ORDER BY a.date DESC, a.morning_in DESC';

    const result = await query(sql, params);
    
    // Format all dates to YYYY-MM-DD string
    const formattedRows = result.rows.map(row => ({
      ...row,
      date: formatDate(row.date)
    }));
    
    res.json({ attendance: formattedRows });
  } catch (error) {
    console.error('Get attendance error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get today's attendance for a student (allows optional date override)
router.get('/today/:studentId', authenticateToken, async (req, res) => {
  try {
    const { studentId } = req.params;
    const { date } = req.query;

    const calculatedDate = date || new Date().toISOString().split('T')[0];
    
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

    const sql = `SELECT a.*, u.full_name
                 FROM attendance a
                 JOIN users u ON a.student_id = u.user_id
                 WHERE a.student_id = $1 AND a.date = $2`;
    
    const params = [studentId, calculatedDate];

    const result = await query(sql, params);

    if (result.rows.length > 0) {
      const attendance = result.rows[0];
      attendance.date = formatDate(attendance.date);
      res.json({ attendance });
    } else {
      res.json({ attendance: null });
    }
  } catch (error) {
    console.error('Get today attendance error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get specific attendance image (lazy loading)
router.get('/:id/image', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await query(
      'SELECT attendance_image FROM attendance WHERE attendance_id = $1',
      [id]
    );

    if (result.rows.length > 0) {
      res.json({ attendance_image: result.rows[0].attendance_image });
    } else {
      res.status(404).json({ error: 'Attendance record not found' });
    }
  } catch (error) {
    console.error('Get attendance image error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Upload attendance photo to Supabase Storage
router.post('/upload-photo', uploadPhoto, async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No photo file provided' });
    }

    // Build unique filename
    const studentId = (req.body && req.body.student_id) || '0';
    const type = (req.body && req.body.photo_type) || 'checkin';
    const ts = Date.now();
    const ext = (req.file.originalname && path.extname(req.file.originalname)) || '.jpg';
    const fileName = `attendance_${studentId}_${ts}_${type}${ext} `;

    // Upload to Supabase Storage
    const result = await uploadAttendancePhoto(req.file.buffer, fileName, req.file.mimetype);

    if (result.error) {
      console.error('Photo upload failed:', result.error);
      return res.status(500).json({ error: result.error });
    }

    res.status(201).json({
      path: result.path,
      publicUrl: result.publicUrl,
      filename: fileName,
    });
  } catch (error) {
    console.error('Upload photo error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

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

    const { student_id, ojt_record_id, date, segment, attendance_image,
      checkin_lat, checkin_lng, accuracy_m, distance_m, inside_geofence, trust_score, trust_flags,
      checkin_photo_path, checkin_photo_captured_at, verification_status: bodyVerificationStatus } = req.body;

    if (!student_id) {
      return res.status(400).json({ error: 'student_id is required' });
    }

    // Fetch supervisor_id for auto-verification
    const supervisorCheck = await query(
      `SELECT supervisor_id FROM ojt_records WHERE student_id = $1 AND status IN('Active', 'Ongoing') LIMIT 1`,
      [student_id]
    );
    const supervisorId = supervisorCheck.rows.length > 0 ? supervisorCheck.rows[0].supervisor_id : null;

    const currentDate = date || new Date().toISOString().split('T')[0];
    const currentTime = new Date().toTimeString().split(' ')[0].substring(0, 8); // HH:MM:SS format

    // STRICT OJT ENROLLMENT CHECK
    // Students can only time-in if they have an active OJT record linked to a coordinator and supervisor
    const routeRole = req.user ? req.user.role : 'Student'; // fallback if authenticateToken is skipped somehow, but it shouldn't be

    // We only enforce this for students submitting their own attendance
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

    // Check if attendance record exists for this date
    const existingRecord = await query(
      'SELECT attendance_id FROM attendance WHERE student_id = $1 AND date = $2',
      [student_id, currentDate]
    );

    let attendanceId;
    let morningIn = null;
    let afternoonIn = null;
    let overtimeIn = null;
    let timeInValue = null;

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

    if (existingRecord.rows.length > 0) {
      // Update existing record
      attendanceId = existingRecord.rows[0].attendance_id;

      // Build update query dynamically based on which segment is being logged
      let updateFields = [];
      let updateValues = [];
      let paramCount = 1;

      if (morningIn !== null) {
        updateFields.push(`morning_in = $${paramCount} `);
        updateValues.push(morningIn);
        paramCount++;
      }
      if (afternoonIn !== null) {
        updateFields.push(`afternoon_in = $${paramCount} `);
        updateValues.push(afternoonIn);
        paramCount++;
      }
      if (overtimeIn !== null) {
        updateFields.push(`overtime_in = $${paramCount} `);
        updateValues.push(overtimeIn);
        paramCount++;
      }

      // Check if this segment is already logged (prevent duplicate)
      const checkResult = await query(
        'SELECT morning_in, afternoon_in, overtime_in FROM attendance WHERE attendance_id = $1',
        [attendanceId]
      );
      const existing = checkResult.rows[0];

      if ((morningIn && existing.morning_in) ||
        (afternoonIn && existing.afternoon_in) ||
        (overtimeIn && existing.overtime_in)) {
        return res.status(400).json({
          error: 'Time in already recorded for this segment',
          errors: [`${segment} already exists for this date`]
        });
      }

      // Add attendance_image if provided
      if (attendance_image) {
        updateFields.push(`attendance_image = $${paramCount} `);
        updateValues.push(attendance_image);
        paramCount++;
      }

      // Auto-approve
      updateFields.push(`status = $${paramCount} `);
      updateValues.push('Approved');
      paramCount++;

      updateFields.push(`verified = $${paramCount} `);
      updateValues.push(true);
      paramCount++;

      if (supervisorId) {
        updateFields.push(`verified_by = $${paramCount} `);
        updateValues.push(supervisorId);
        paramCount++;
      }

      updateFields.push(`verified_at = CURRENT_TIMESTAMP`);

      updateValues.push(attendanceId);
      const updateSql = `
        UPDATE attendance 
        SET ${updateFields.join(', ')}, updated_at = CURRENT_TIMESTAMP
        WHERE attendance_id = $${paramCount}
        RETURNING attendance_id
      `;


      await query(updateSql, updateValues);

    } else {
      // Create new record
      const result = await query(
        'SELECT create_attendance($1::integer, $2::date, $3::time, NULL::time, $4::time, NULL::time) as result',
        [student_id, currentDate, morningIn, afternoonIn]
      );

      const response = result.rows[0].result;

      if (!response.success) {
        return res.status(400).json({
          error: 'Validation failed',
          errors: response.errors
        });
      }

      attendanceId = response.attendance_id;

      // If we need to set overtime_in, update it separately
      if (overtimeIn) {
        await query(
          'UPDATE attendance SET overtime_in = $1 WHERE attendance_id = $2',
          [overtimeIn, attendanceId]
        );
      }

      // Save attendance_image if provided
      if (attendance_image) {
        await query(
          'UPDATE attendance SET attendance_image = $1 WHERE attendance_id = $2',
          [attendance_image, attendanceId]
        );
      }

      // Auto-approve new record
      await query(
        `UPDATE attendance 
         SET status = 'Approved',
  verified = true,
  verified_by = $1,
  verified_at = CURRENT_TIMESTAMP 
         WHERE attendance_id = $2`,
        [supervisorId, attendanceId]
      );
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
    if (checkin_photo_captured_at != null && String(checkin_photo_captured_at).trim()) {
      geoParts.push(`checkin_photo_captured_at = $${p++} `); geoVals.push(String(checkin_photo_captured_at).trim());
    }
    const verStatus = bodyVerificationStatus || computeVerificationStatus(inside_geofence, tscore ?? trust_score, 60);
    const finalVerStatus = verStatus === 'AUTO_VERIFIED' ? 'AUTO_APPROVED' : verStatus;
    geoParts.push(`verification_status = $${p++} `); geoVals.push(finalVerStatus);

    geoVals.push(attendanceId);
    try {
      await query(
        `UPDATE attendance SET ${geoParts.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE attendance_id = $${p} `,
        geoVals
      );
    } catch (err) {
      console.warn('Optional attendance columns may not exist:', err.message);
    }

    // Get the updated/created attendance record
    const attendanceResult = await query(
      'SELECT get_attendance($1) as attendance',
      [attendanceId]
    );

    const savedAttendance = attendanceResult.rows[0].attendance;
    console.log("✅ [Attendance POST /time-in] Attendance saved:", {
      attendance_id: savedAttendance?.attendance_id,
      student_id: savedAttendance?.student_id,
      date: savedAttendance?.date,
      status: savedAttendance?.status || 'Pending',
      time_in: savedAttendance?.morning_in || savedAttendance?.afternoon_in || savedAttendance?.overtime_in
    });

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
      checkin_photo_path, checkout_photo_path, checkin_photo_captured_at, checkout_photo_captured_at, verification_status: bodyVerificationStatus } = req.body;

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
      'SELECT morning_out, afternoon_out, overtime_out FROM attendance WHERE attendance_id = $1',
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
      return res.status(400).json({ error: 'Invalid segment value' });
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

    updateValues.push(attendanceId);
    const updateSql = `
        UPDATE attendance 
        SET ${updateFields.join(', ')}, updated_at = CURRENT_TIMESTAMP
        WHERE attendance_id = $${paramCount}
        RETURNING *
      `;

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

module.exports = router;

