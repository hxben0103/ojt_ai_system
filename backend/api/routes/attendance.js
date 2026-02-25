const express = require('express');
const router = express.Router();
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const { query } = require('../../config/db');
const jwt = require('jsonwebtoken');

// Photo upload: store under backend/uploads/attendance_photos/
const uploadDir = path.join(__dirname, '../../uploads/attendance_photos');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}
const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const studentId = (req.body && req.body.student_id) || '0';
    const type = (req.body && req.body.photo_type) || 'checkin';
    const ts = Date.now();
    const ext = (file.originalname && path.extname(file.originalname)) || '.jpg';
    cb(null, `attendance_${studentId}_${ts}_${type}${ext}`);
  }
});
const uploadPhoto = multer({ storage, limits: { fileSize: 10 * 1024 * 1024 } }).single('photo');

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
function safeInt(v) {
  if (v == null) return null;
  const n = parseInt(v, 10);
  return Number.isFinite(n) ? n : null;
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
router.get('/', async (req, res) => {
  try {
    const { student_id, date, verification_status } = req.query;

    let sql = `
      SELECT a.*, u.full_name
      FROM attendance a
      JOIN users u ON a.student_id = u.user_id
      WHERE 1=1
    `;
    const params = [];
    let paramCount = 1;

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

    sql += ' ORDER BY a.date DESC, a.time_in DESC';

    const result = await query(sql, params);
    res.json({ attendance: result.rows });
  } catch (error) {
    console.error('Get attendance error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get today's attendance for a student
router.get('/today/:studentId', async (req, res) => {
  try {
    const { studentId } = req.params;
    // Use PostgreSQL's CURRENT_DATE to avoid timezone issues
    // This ensures we match the date in the database's timezone
    const result = await query(
      `SELECT a.*, u.full_name 
       FROM attendance a
       JOIN users u ON a.student_id = u.user_id
       WHERE a.student_id = $1 AND a.date = CURRENT_DATE`,
      [studentId]
    );
    
    if (result.rows.length > 0) {
      res.json({ attendance: result.rows[0] });
    } else {
      res.json({ attendance: null });
    }
  } catch (error) {
    console.error('Get today attendance error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Upload attendance photo (multipart); returns relative path for checkin_photo_path / checkout_photo_path
router.post('/upload-photo', uploadPhoto, (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No photo file provided' });
    }
    const relativePath = path.join('attendance_photos', req.file.filename).replace(/\\/g, '/');
    res.status(201).json({ path: relativePath, filename: req.file.filename });
  } catch (error) {
    console.error('Upload photo error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create attendance record (Time In) - Using stored procedure
// Supports both legacy time_in and segment-based logging
router.post('/time-in', async (req, res) => {
  try {
    console.log("📝 [Attendance POST /time-in] Saving attendance:", {
      student_id: req.body.student_id,
      date: req.body.date,
      segment: req.body.segment,
      time_in: req.body.time_in,
      has_image: !!req.body.attendance_image
    });

    const { student_id, ojt_record_id, date, segment, time_in, attendance_image,
      checkin_lat, checkin_lng, accuracy_m, distance_m, inside_geofence, trust_score, trust_flags,
      checkin_photo_path, checkin_photo_captured_at, verification_status: bodyVerificationStatus } = req.body;

    if (!student_id) {
      return res.status(400).json({ error: 'student_id is required' });
    }

    const currentDate = date || new Date().toISOString().split('T')[0];
    const currentTime = time_in || new Date().toTimeString().split(' ')[0].substring(0, 8); // HH:MM:SS format

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
      switch (segment) {
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
          timeInValue = currentTime;
      }
    } else {
      // Legacy support: use time_in if no segment specified
      timeInValue = currentTime;
    }

    if (existingRecord.rows.length > 0) {
      // Update existing record
      attendanceId = existingRecord.rows[0].attendance_id;
      
      // Build update query dynamically based on which segment is being logged
      let updateFields = [];
      let updateValues = [];
      let paramCount = 1;

      if (morningIn !== null) {
        updateFields.push(`morning_in = $${paramCount}`);
        updateValues.push(morningIn);
        paramCount++;
      }
      if (afternoonIn !== null) {
        updateFields.push(`afternoon_in = $${paramCount}`);
        updateValues.push(afternoonIn);
        paramCount++;
      }
      if (overtimeIn !== null) {
        updateFields.push(`overtime_in = $${paramCount}`);
        updateValues.push(overtimeIn);
        paramCount++;
      }
      if (timeInValue !== null && !morningIn && !afternoonIn && !overtimeIn) {
        updateFields.push(`time_in = $${paramCount}`);
        updateValues.push(timeInValue);
        paramCount++;
      }

      if (updateFields.length === 0) {
        return res.status(400).json({ error: 'Invalid segment or time_in value' });
      }

      // Check if this segment is already logged (prevent duplicate)
      const checkRecord = await query(
        'SELECT morning_in, afternoon_in, overtime_in, time_in FROM attendance WHERE attendance_id = $1',
        [attendanceId]
      );
      const existing = checkRecord.rows[0];
      
      if ((morningIn && existing.morning_in) || 
          (afternoonIn && existing.afternoon_in) || 
          (overtimeIn && existing.overtime_in) ||
          (timeInValue && existing.time_in && !morningIn && !afternoonIn && !overtimeIn)) {
        return res.status(400).json({ 
          error: 'Time in already recorded for this segment',
          errors: [`${segment || 'time_in'} already exists for this date`]
        });
      }

      // Add attendance_image if provided
      if (attendance_image) {
        updateFields.push(`attendance_image = $${paramCount}`);
        updateValues.push(attendance_image);
        paramCount++;
      }
      
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
        'SELECT create_attendance($1, $2, $3, NULL, $4, NULL, $5, NULL) as result',
        [student_id, currentDate, timeInValue || morningIn || afternoonIn || overtimeIn, morningIn, afternoonIn]
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
    }

    // Optional geofence/trust/photo/verification: store if columns exist (backward compatible)
    const geoParts = [];
    const geoVals = [];
    let p = 1;
    const clat = safeFloat(checkin_lat); const clng = safeFloat(checkin_lng);
    if (clat != null) { geoParts.push(`checkin_lat = $${p++}`); geoVals.push(clat); }
    if (clng != null) { geoParts.push(`checkin_lng = $${p++}`); geoVals.push(clng); }
    const acc = safeFloat(accuracy_m); const dist = safeFloat(distance_m);
    if (acc != null) { geoParts.push(`accuracy_m = $${p++}`); geoVals.push(acc); }
    if (dist != null) { geoParts.push(`distance_m = $${p++}`); geoVals.push(dist); }
    if (inside_geofence != null) { geoParts.push(`inside_geofence = $${p++}`); geoVals.push(inside_geofence); }
    const tscore = safeInt(trust_score);
    if (tscore != null) { geoParts.push(`trust_score = $${p++}`); geoVals.push(tscore); }
    if (trust_flags != null) {
      const trustFlagsStr = Array.isArray(trust_flags) ? JSON.stringify(trust_flags) : String(trust_flags);
      geoParts.push(`trust_flags = $${p++}`); geoVals.push(trustFlagsStr);
    }
    if (checkin_photo_path != null && String(checkin_photo_path).trim()) {
      geoParts.push(`checkin_photo_path = $${p++}`); geoVals.push(String(checkin_photo_path).trim());
    }
    if (checkin_photo_captured_at != null && String(checkin_photo_captured_at).trim()) {
      geoParts.push(`checkin_photo_captured_at = $${p++}`); geoVals.push(String(checkin_photo_captured_at).trim());
    }
    const verStatus = bodyVerificationStatus || computeVerificationStatus(inside_geofence, tscore ?? trust_score, 60);
    geoParts.push(`verification_status = $${p++}`); geoVals.push(verStatus);
    geoVals.push(attendanceId);
    try {
      await query(
        `UPDATE attendance SET ${geoParts.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE attendance_id = $${p}`,
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
      time_in: savedAttendance?.time_in || savedAttendance?.morning_in || savedAttendance?.afternoon_in
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
router.put('/time-out', async (req, res) => {
  try {
    const { attendance_id, student_id, date, segment, time_out, attendance_image,
      checkin_lat, checkin_lng, checkout_lat, checkout_lng, accuracy_m, distance_m, inside_geofence, trust_score, trust_flags,
      checkin_photo_path, checkout_photo_path, checkin_photo_captured_at, checkout_photo_captured_at, verification_status: bodyVerificationStatus } = req.body;

    const currentTime = time_out || new Date().toTimeString().split(' ')[0].substring(0, 8); // HH:MM:SS format

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

    let morningOut = null;
    let afternoonOut = null;
    let overtimeOut = null;
    let timeOutValue = null;

    // Map segment to appropriate field
    if (segment) {
      switch (segment) {
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
          timeOutValue = currentTime;
      }
    } else {
      // Legacy support: use time_out if no segment specified
      timeOutValue = currentTime;
    }

    // Check if this segment is already logged (prevent duplicate)
    const checkRecord = await query(
      'SELECT morning_out, afternoon_out, overtime_out, time_out FROM attendance WHERE attendance_id = $1',
      [attendanceId]
    );
    
    if (checkRecord.rows.length === 0) {
      return res.status(404).json({ error: 'Attendance record not found' });
    }

    const existing = checkRecord.rows[0];
    
    if ((morningOut && existing.morning_out) || 
        (afternoonOut && existing.afternoon_out) || 
        (overtimeOut && existing.overtime_out) ||
        (timeOutValue && existing.time_out && !morningOut && !afternoonOut && !overtimeOut)) {
      return res.status(400).json({ 
        error: 'Time out already recorded for this segment',
        errors: [`${segment || 'time_out'} already exists for this record`]
      });
    }

    // Build update query dynamically
    let updateFields = [];
    let updateValues = [];
    let paramCount = 1;

    if (morningOut !== null) {
      updateFields.push(`morning_out = $${paramCount}`);
      updateValues.push(morningOut);
      paramCount++;
    }
    if (afternoonOut !== null) {
      updateFields.push(`afternoon_out = $${paramCount}`);
      updateValues.push(afternoonOut);
      paramCount++;
    }
    if (overtimeOut !== null) {
      updateFields.push(`overtime_out = $${paramCount}`);
      updateValues.push(overtimeOut);
      paramCount++;
    }
    if (timeOutValue !== null && !morningOut && !afternoonOut && !overtimeOut) {
      updateFields.push(`time_out = $${paramCount}`);
      updateValues.push(timeOutValue);
      paramCount++;
    }

    if (updateFields.length === 0) {
      return res.status(400).json({ error: 'Invalid segment or time_out value' });
    }

    // Add attendance_image if provided
    if (attendance_image) {
      updateFields.push(`attendance_image = $${paramCount}`);
      updateValues.push(attendance_image);
      paramCount++;
    }

    updateValues.push(attendanceId);
    const updateSql = `
      UPDATE attendance 
      SET ${updateFields.join(', ')}, updated_at = CURRENT_TIMESTAMP
      WHERE attendance_id = $${paramCount}
      RETURNING attendance_id
    `;
    
    await query(updateSql, updateValues);

    // Optional geofence/trust/checkout/photo/verification (time-out)
    const geoParts = [];
    const geoVals = [];
    let p = 1;
    const clat = safeFloat(checkin_lat); const clng = safeFloat(checkin_lng);
    if (clat != null) { geoParts.push(`checkin_lat = $${p++}`); geoVals.push(clat); }
    if (clng != null) { geoParts.push(`checkin_lng = $${p++}`); geoVals.push(clng); }
    const outLat = safeFloat(checkout_lat); const outLng = safeFloat(checkout_lng);
    if (outLat != null) { geoParts.push(`checkout_lat = $${p++}`); geoVals.push(outLat); }
    if (outLng != null) { geoParts.push(`checkout_lng = $${p++}`); geoVals.push(outLng); }
    const acc = safeFloat(accuracy_m); const dist = safeFloat(distance_m);
    if (acc != null) { geoParts.push(`accuracy_m = $${p++}`); geoVals.push(acc); }
    if (dist != null) { geoParts.push(`distance_m = $${p++}`); geoVals.push(dist); }
    if (inside_geofence != null) { geoParts.push(`inside_geofence = $${p++}`); geoVals.push(inside_geofence); }
    const tscore = safeInt(trust_score);
    if (tscore != null) { geoParts.push(`trust_score = $${p++}`); geoVals.push(tscore); }
    if (trust_flags != null) {
      const trustFlagsStr = Array.isArray(trust_flags) ? JSON.stringify(trust_flags) : String(trust_flags);
      geoParts.push(`trust_flags = $${p++}`); geoVals.push(trustFlagsStr);
    }
    if (checkout_photo_path != null && String(checkout_photo_path).trim()) {
      geoParts.push(`checkout_photo_path = $${p++}`); geoVals.push(String(checkout_photo_path).trim());
    }
    if (checkout_photo_captured_at != null && String(checkout_photo_captured_at).trim()) {
      geoParts.push(`checkout_photo_captured_at = $${p++}`); geoVals.push(String(checkout_photo_captured_at).trim());
    }
    const verStatus = bodyVerificationStatus || computeVerificationStatus(inside_geofence, tscore ?? trust_score, 60);
    geoParts.push(`verification_status = $${p++}`); geoVals.push(verStatus);
    geoVals.push(attendanceId);
    try {
      await query(
        `UPDATE attendance SET ${geoParts.join(', ')}, updated_at = CURRENT_TIMESTAMP WHERE attendance_id = $${p}`,
        geoVals
      );
    } catch (err) {
      console.warn('Optional attendance columns may not exist:', err.message);
    }

    // Calculate and update total_hours after time-out is recorded
    // This handles both segment-based (morning/afternoon) and legacy (time_in/time_out) logging
    await query(`
      UPDATE attendance
      SET total_hours = CASE
        -- Segment-based: morning + afternoon segments
        WHEN morning_in IS NOT NULL AND morning_out IS NOT NULL 
             AND afternoon_in IS NOT NULL AND afternoon_out IS NOT NULL THEN
          (EXTRACT(EPOCH FROM (morning_out - morning_in)) / 3600.0) +
          (EXTRACT(EPOCH FROM (afternoon_out - afternoon_in)) / 3600.0)
        -- Segment-based: morning_in to afternoon_out (if afternoon_in is missing)
        WHEN morning_in IS NOT NULL AND afternoon_out IS NOT NULL THEN
          EXTRACT(EPOCH FROM (afternoon_out - morning_in)) / 3600.0
        -- Legacy: time_in to time_out
        WHEN time_in IS NOT NULL AND time_out IS NOT NULL THEN
          EXTRACT(EPOCH FROM (time_out - time_in)) / 3600.0
        ELSE total_hours
      END
      WHERE attendance_id = $1
    `, [attendanceId]);

    // Get the updated attendance record
    const attendanceResult = await query(
      'SELECT get_attendance($1) as attendance',
      [attendanceId]
    );
    
    res.json({
      message: 'Time out recorded successfully',
      attendance: attendanceResult.rows[0].attendance
    });
  } catch (error) {
    console.error('Time out error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get attendance summary - Using stored procedure
router.get('/summary', async (req, res) => {
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
router.get('/summary/:studentId', async (req, res) => {
  try {
    const { studentId } = req.params;

    let statsRow = {};
    let studentName = 'N/A';
    let lastDutyDate = null;

    try {
      // Compute summary directly from attendance table, using only APPROVED records.
      const summaryResult = await query(
        `SELECT 
           COALESCE(SUM(total_hours), 0)          AS total_hours_completed,
           COALESCE(COUNT(DISTINCT date), 0)      AS total_days_present,
           CASE 
             WHEN COALESCE(COUNT(DISTINCT date),0) > 0 
               THEN COALESCE(SUM(total_hours),0) / COALESCE(NULLIF(COUNT(DISTINCT date),0),1)
             ELSE 0
           END                                    AS avg_hours_per_day
         FROM attendance
         WHERE student_id = $1
           AND status = 'Approved'`,
      [studentId]
    );
    
      statsRow = summaryResult.rows[0] || {};
    
    // CRITICAL: Only get last duty date from approved attendance
    const lastDutyResult = await query(
      'SELECT MAX(date) as last_duty_date FROM attendance WHERE student_id = $1 AND status = \'Approved\'',
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
       RETURNING *`,
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
      updateFields.push(`verified_by = $${paramCount}`);
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
       RETURNING *`,
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
       RETURNING *`,
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

