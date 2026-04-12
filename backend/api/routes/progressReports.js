const express = require('express');
const router = express.Router();
const { query } = require('../../config/db');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const jwt = require('jsonwebtoken');

// ✅ Security: Enforce JWT_SECRET from environment — never use a fallback
const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET) {
  console.error('❌ FATAL: JWT_SECRET environment variable is not set. Please configure your .env file.');
  process.exit(1);
}

// Authentication middleware
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Access token required' });
  }

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ error: 'Invalid or expired token' });
    }
    req.user = user;
    next();
  });
};

// Configure multer for file uploads
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    const uploadDir = path.join(__dirname, '../../uploads/reports');
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    const studentId = req.body.student_id || 'unknown';
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, `WPR-${studentId}-${uniqueSuffix}${path.extname(file.originalname)}`);
  }
});

const upload = multer({ 
  storage: storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB limit
  fileFilter: (req, file, cb) => {
    const allowedTypes = ['.pdf', '.doc', '.docx'];
    const ext = path.extname(file.originalname).toLowerCase();
    if (allowedTypes.includes(ext)) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type. Only PDF, DOC, and DOCX are allowed.'));
    }
  }
});

// Create a new progress report
router.post('/', authenticateToken, upload.single('report_file'), async (req, res) => {
  try {
    const { student_id, title, description, week_number, report_date } = req.body;
    const { role, user_id: loggedInUserId } = req.user;

    // Data Isolation: Students can only upload for themselves
    if (role === 'Student' && student_id != loggedInUserId) {
        return res.status(403).json({ error: 'Access Denied', message: 'You can only upload reports for yourself.' });
    }
    
    if (!req.file) {
      return res.status(400).json({ error: 'Please upload a file' });
    }

    const filePath = req.file.path;
    const fileName = req.file.originalname;

    const result = await query(
      `INSERT INTO student_progress_reports 
       (student_id, title, description, file_path, file_name, week_number, report_date) 
       VALUES ($1, $2, $3, $4, $5, $6, $7) 
       RETURNING *`,
      [student_id, title, description, filePath, fileName, week_number || null, report_date || new Date()]
    );

    res.status(201).json({
      message: 'Progress report uploaded successfully',
      report: result.rows[0]
    });
  } catch (error) {
    console.error('Upload progress report error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get reports for a student
router.get('/student/:student_id', authenticateToken, async (req, res) => {
  try {
    const { student_id } = req.params;
    const { role, user_id: loggedInUserId } = req.user;

    // Data Isolation: Check access
    if (role === 'Student' && student_id != loggedInUserId) {
        return res.status(403).json({ error: 'Access Denied' });
    }
    if (role === 'Coordinator') {
        const accessCheck = await query(
            "SELECT record_id FROM ojt_records WHERE student_id = $1 AND coordinator_id = $2 AND status IN ('Ongoing', 'Active') LIMIT 1",
            [student_id, loggedInUserId]
        );
        if (accessCheck.rows.length === 0) {
            return res.status(403).json({ error: 'Access Denied', message: 'You can only view reports for students assigned to you.' });
        }
    }
    const result = await query(
      'SELECT * FROM student_progress_reports WHERE student_id = $1 ORDER BY created_at DESC',
      [student_id]
    );
    res.json({ reports: result.rows });
  } catch (error) {
    console.error('Get student reports error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get all reports (for coordinators/admins)
router.get('/', authenticateToken, async (req, res) => {
  try {
    const { status, student_id } = req.query;
    const { role, user_id: loggedInUserId } = req.user;

    let sql = `
      SELECT r.*, u.full_name as student_name 
      FROM student_progress_reports r
      JOIN users u ON r.student_id = u.user_id
      -- Join OJT records for coordinator filtering
      LEFT JOIN ojt_records o ON r.student_id = o.student_id AND o.status IN ('Ongoing', 'Active')
      WHERE 1=1
    `;
    const params = [];
    let p = 1;

    // Data Isolation: Coordinators can only see their students' reports
    if (role === 'Coordinator') {
      sql += ` AND o.coordinator_id = $${p++}`;
      params.push(loggedInUserId);
    }

    if (status) {
      sql += ` AND r.status = $${p++}`;
      params.push(status);
    }
    if (student_id) {
      sql += ` AND r.student_id = $${p++}`;
      params.push(student_id);
    }

    sql += ' ORDER BY r.created_at DESC';

    const result = await query(sql, params);
    res.json({ reports: result.rows });
  } catch (error) {
    console.error('Get all reports error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update report status (for reviews)
router.put('/:id/status', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { status, feedback } = req.body;

    const result = await query(
      'UPDATE student_progress_reports SET status = $1, feedback = $2, updated_at = CURRENT_TIMESTAMP WHERE report_id = $3 RETURNING *',
      [status, feedback, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Report not found' });
    }

    res.json({
      message: 'Report status updated successfully',
      report: result.rows[0]
    });
  } catch (error) {
    console.error('Update report status error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Download report file
router.get('/:id/download', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const result = await query('SELECT file_path, file_name FROM student_progress_reports WHERE report_id = $1', [id]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Report not found' });
    }

    const { file_path: filePath, file_name: fileName } = result.rows[0];
    
    if (fs.existsSync(filePath)) {
      res.download(filePath, fileName);
    } else {
      res.status(404).json({ error: 'File not found on server' });
    }
  } catch (error) {
    console.error('Download report error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
