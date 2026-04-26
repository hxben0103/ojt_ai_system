const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { query } = require('../../config/db');
const authenticateToken = require('../middleware/auth');

// ✅ Security: Enforce JWT_SECRET from environment — never use a fallback
const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET) {
  console.error('❌ FATAL: JWT_SECRET environment variable is not set. Please configure your .env file.');
  process.exit(1);
}

// Register User
router.post('/register', async (req, res) => {
  try {
    const {
      full_name,
      email,
      password,
      role,
      // Student fields
      student_id,
      course,
      age,
      gender,
      contact_number,
      address,
      required_hours,
      profile_photo,
      program, // New field for Phase 4
      // Supervisor/Coordinator fields (can be stored in address or contact_number)
    } = req.body;

    // Log received data for debugging
    console.log('Registration data received:', {
      full_name,
      email,
      role,
      student_id,
      course,
      age,
      gender,
      contact_number,
      address,
      required_hours,
      program,
      profile_photo: profile_photo ? `${profile_photo.substring(0, 50)}...` : null
    });

    // Validate required fields
    if (!full_name || !email || !password || !role) {
      return res.status(400).json({
        error: 'Missing required fields. Please provide full_name, email, password, and role.'
      });
    }

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return res.status(400).json({ error: 'Invalid email format' });
    }

    // Validate password length
    if (password.length < 6) {
      return res.status(400).json({ error: 'Password must be at least 6 characters long' });
    }

    // Validate role
    const validRoles = ['Admin', 'Coordinator', 'Supervisor', 'Student'];
    if (!validRoles.includes(role)) {
      return res.status(400).json({
        error: `Invalid role. Must be one of: ${validRoles.join(', ')}`
      });
    }

    // Check if user already exists
    const existingUser = await query(
      'SELECT * FROM users WHERE email = $1',
      [email]
    );

    if (existingUser.rows.length > 0) {
      return res.status(400).json({ error: 'User already exists' });
    }

    // Hash password
    const password_hash = await bcrypt.hash(password, 10);

    // Set status based on role: Coordinators need Admin approval, Students/Supervisors need Coordinator approval
    // Admin accounts are created as Active (if needed in future)
    let initialStatus = 'Pending';
    if (role === 'Admin') {
      initialStatus = 'Active'; // Admins are auto-approved
    }

    // Insert user with all fields
    const result = await query(
      `INSERT INTO users (
        full_name, email, password_hash, role, status,
        student_id, course, age, gender, contact_number, 
        address, required_hours, profile_photo, program
      )
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
       RETURNING *`,
      [
        full_name,
        email,
        password_hash,
        role,
        initialStatus,
        (student_id && String(student_id).trim() !== '') ? String(student_id).trim() : null,
        (course && String(course).trim() !== '') ? String(course).trim() : null,
        (age !== undefined && age !== null && String(age).trim() !== '') ? (() => {
          const ageNum = typeof age === 'number' ? age : parseInt(String(age));
          return isNaN(ageNum) ? null : ageNum;
        })() : null,
        (gender && String(gender).trim() !== '') ? String(gender).trim() : null,
        (contact_number && String(contact_number).trim() !== '') ? String(contact_number).trim() : null,
        (address && String(address).trim() !== '') ? String(address).trim() : null,
        (required_hours !== undefined && required_hours !== null && String(required_hours).trim() !== '') ? (() => {
          const hoursNum = typeof required_hours === 'number' ? required_hours : parseInt(String(required_hours));
          return isNaN(hoursNum) ? null : hoursNum;
        })() : null,
        (profile_photo && String(profile_photo).trim() !== '') ? String(profile_photo).trim() : null,
        (program && String(program).trim() !== '') ? String(program).trim() : 'Not Specified'
      ]
    );

    const user = result.rows[0];

    // Log saved user data for verification
    console.log('User saved successfully:', {
      user_id: user.user_id,
      full_name: user.full_name,
      email: user.email,
      role: user.role,
      status: user.status,
      student_id: user.student_id,
      course: user.course,
      age: user.age,
      gender: user.gender,
      contact_number: user.contact_number,
      address: user.address ? user.address.substring(0, 50) + '...' : null,
      required_hours: user.required_hours,
      profile_photo: user.profile_photo ? 'Present' : 'Not present'
    });

    // Determine approval message based on role
    let approvalMessage = 'User registered successfully';
    if (role === 'Coordinator') {
      approvalMessage = 'Registration submitted successfully! Please wait for Admin approval.';
    } else if (role === 'Student' || role === 'Supervisor') {
      approvalMessage = 'Registration submitted successfully! Please wait for Coordinator approval.';
    }

    // Don't generate token for pending users - they need approval first
    let token = null;
    if (user.status === 'Active') {
      token = jwt.sign(
        { user_id: user.user_id, email: user.email, role: user.role },
        JWT_SECRET,
        { expiresIn: '7d' }
      );
    }

    // Return all user data
    res.status(201).json({
      message: approvalMessage,
      user: {
        user_id: user.user_id,
        full_name: user.full_name,
        email: user.email,
        role: user.role,
        status: user.status,
        student_id: user.student_id,
        course: user.course,
        age: user.age,
        gender: user.gender,
        contact_number: user.contact_number,
        address: user.address,
        required_hours: user.required_hours,
        profile_photo: user.profile_photo,
        date_created: user.date_created
      },
      token: token
    });
  } catch (error) {
    console.error('Registration error:', error);
    console.error('Error details:', {
      message: error.message,
      stack: error.stack,
      code: error.code
    });

    // Return more detailed error message in development
    const errorMessage = process.env.NODE_ENV === 'development'
      ? error.message || 'Internal server error'
      : 'Internal server error';

    res.status(500).json({
      error: errorMessage,
      details: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
  }
});

// Login User
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    // Find user by email or student_id
    const result = await query(
      'SELECT * FROM users WHERE email = $1 OR student_id = $1',
      [email]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid ID/Email or password' });
    }

    const user = result.rows[0];

    // Check password
    const isValidPassword = await bcrypt.compare(password, user.password_hash);

    if (!isValidPassword) {
      return res.status(401).json({ error: 'Invalid ID/Email or password' });
    }

    // Check if user is active (Admin users can always log in regardless of status)
    if (user.role !== 'Admin' && user.status !== 'Active') {
      if (user.status === 'Pending') {
        return res.status(403).json({
          error: 'Account is pending approval. Please wait for administrator approval.',
          status: 'Pending'
        });
      }
      return res.status(403).json({ error: 'Account is not active' });
    }

    // Generate JWT token
    const token = jwt.sign(
      { user_id: user.user_id, email: user.email, role: user.role },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    res.json({
      message: 'Login successful',
      user: {
        user_id: user.user_id,
        full_name: user.full_name,
        email: user.email,
        role: user.role,
        status: user.status,
        student_id: user.student_id,
        course: user.course,
        age: user.age,
        gender: user.gender,
        contact_number: user.contact_number,
        address: user.address,
        required_hours: user.required_hours,
        profile_photo: user.profile_photo,
        date_created: user.date_created
      },
      token
    });
  } catch (error) {
    console.error('Login error:', error);
    console.error('Login error details:', {
      message: error.message,
      stack: error.stack,
      code: error.code
    });
    // Return more detailed error in development
    const errorMessage = process.env.NODE_ENV === 'development'
      ? `Internal server error: ${error.message}`
      : 'Internal server error';
    res.status(500).json({
      error: errorMessage,
      details: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
  }
});

// Get User Profile
// E10 FIX: Use shared authenticateToken middleware instead of manual JWT verification
// This ensures query-param token fallback works and error messages are consistent
router.get('/profile', authenticateToken, async (req, res) => {
  try {
    const result = await query(
      'SELECT * FROM users WHERE user_id = $1',
      [req.user.user_id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    const user = result.rows[0];
    res.json({
      user: {
        user_id: user.user_id,
        full_name: user.full_name,
        email: user.email,
        role: user.role,
        status: user.status,
        student_id: user.student_id,
        course: user.course,
        age: user.age,
        gender: user.gender,
        contact_number: user.contact_number,
        address: user.address,
        required_hours: user.required_hours,
        profile_photo: user.profile_photo,
        date_created: user.date_created
      }
    });
  } catch (error) {
    console.error('Profile error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get All Users (Admin only)
router.get('/users', authenticateToken, async (req, res) => {
  try {
    // Only Admin and Coordinator can list users
    if (req.user.role !== 'Admin' && req.user.role !== 'Coordinator') {
      return res.status(403).json({ error: 'Access denied: insufficient permissions' });
    }

    const result = await query(
      'SELECT user_id, full_name, email, role, status, date_created, course, program FROM users ORDER BY date_created DESC'
    );

    res.json({ users: result.rows });
  } catch (error) {
    console.error('Get users error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});



// Get Pending Users
// Admin can see pending Coordinators
// Coordinator can see pending Students and Supervisors
router.get('/pending', authenticateToken, async (req, res) => {
  try {
    const { role, user_id } = req.user;
    let result;

    if (role === 'Admin') {
      // Admin can see pending Coordinators
      result = await query(
        `SELECT user_id, full_name, email, role, status, student_id, course, 
         age, gender, contact_number, address, date_created 
         FROM users 
         WHERE role = 'Coordinator' AND status = 'Pending' 
         ORDER BY date_created DESC`
      );
    } else if (role === 'Coordinator') {
      // Program-Bound Approval: Coordinator only sees pending Students
      // whose course matches the coordinator's own course/program.
      // Supervisors are not program-bound, so all coordinators can see them.
      const coordResult = await query(
        'SELECT course FROM users WHERE user_id = $1',
        [user_id]
      );
      const coordCourse = coordResult.rows[0]?.course || null;

      if (coordCourse) {
        // Coordinator has a program set — show matching students + all supervisors
        result = await query(
          `SELECT user_id, full_name, email, role, status, student_id, course, 
           age, gender, contact_number, address, date_created 
           FROM users 
           WHERE status = 'Pending' 
             AND (
               (role = 'Student' AND course = $1)
               OR role = 'Supervisor'
             )
           ORDER BY date_created DESC`,
          [coordCourse]
        );
      } else {
        // Coordinator has no program set — fallback: show all pending (backward compat)
        result = await query(
          `SELECT user_id, full_name, email, role, status, student_id, course, 
           age, gender, contact_number, address, date_created 
           FROM users 
           WHERE role IN ('Student', 'Supervisor') AND status = 'Pending' 
           ORDER BY date_created DESC`
        );
      }
    } else {
      return res.status(403).json({ error: 'You do not have permission to view pending users' });
    }

    res.json({ pendingUsers: result.rows });
  } catch (error) {
    console.error('Get pending users error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Approve User
// Admin can approve Coordinators
// Coordinator can approve Students and Supervisors
router.put('/approve/:userId', authenticateToken, async (req, res) => {
  try {
    const { role } = req.user;
    const { userId } = req.params;

    // Get the user to be approved
    const userResult = await query(
      'SELECT * FROM users WHERE user_id = $1',
      [userId]
    );

    if (userResult.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    const userToApprove = userResult.rows[0];

    // Check permissions
    if (role === 'Admin' && userToApprove.role === 'Coordinator') {
      // Admin approving Coordinator - allowed
    } else if (role === 'Coordinator' && (userToApprove.role === 'Student' || userToApprove.role === 'Supervisor')) {
      // Program-Bound Check: Coordinator can only approve Students from their own program
      if (userToApprove.role === 'Student') {
        const coordResult = await query(
          'SELECT course FROM users WHERE user_id = $1',
          [req.user.user_id]
        );
        const coordCourse = coordResult.rows[0]?.course || null;
        if (coordCourse && userToApprove.course && coordCourse !== userToApprove.course) {
          return res.status(403).json({
            error: `You can only approve students from your program (${coordCourse}). This student belongs to ${userToApprove.course}.`
          });
        }
      }
      // Supervisor approval — no program restriction
    } else {
      return res.status(403).json({
        error: 'You do not have permission to approve this user'
      });
    }

    // Check if user is already approved
    if (userToApprove.status === 'Active') {
      return res.status(400).json({ error: 'User is already approved' });
    }

    // Update user status to Active
    const updateResult = await query(
      'UPDATE users SET status = $1 WHERE user_id = $2 RETURNING *',
      ['Active', userId]
    );

    const approvedUser = updateResult.rows[0];

    res.json({
      message: 'User approved successfully',
      user: {
        user_id: approvedUser.user_id,
        full_name: approvedUser.full_name,
        email: approvedUser.email,
        role: approvedUser.role,
        status: approvedUser.status
      }
    });
  } catch (error) {
    console.error('Approve user error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Reject User (optional - set status to Rejected)
router.put('/reject/:userId', authenticateToken, async (req, res) => {
  try {
    const { role } = req.user;
    const { userId } = req.params;

    // Get the user to be rejected
    const userResult = await query(
      'SELECT * FROM users WHERE user_id = $1',
      [userId]
    );

    if (userResult.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    const userToReject = userResult.rows[0];

    // Check permissions
    if (role === 'Admin' && userToReject.role === 'Coordinator') {
      // Admin rejecting Coordinator - allowed
    } else if (role === 'Coordinator' && (userToReject.role === 'Student' || userToReject.role === 'Supervisor')) {
      // Program-Bound Check: Coordinator can only reject Students from their own program
      if (userToReject.role === 'Student') {
        const coordResult = await query(
          'SELECT course FROM users WHERE user_id = $1',
          [req.user.user_id]
        );
        const coordCourse = coordResult.rows[0]?.course || null;
        if (coordCourse && userToReject.course && coordCourse !== userToReject.course) {
          return res.status(403).json({
            error: `You can only reject students from your program (${coordCourse}). This student belongs to ${userToReject.course}.`
          });
        }
      }
      // Supervisor rejection — no program restriction
    } else {
      return res.status(403).json({
        error: 'You do not have permission to reject this user'
      });
    }

    // Update user status to Rejected
    const updateResult = await query(
      'UPDATE users SET status = $1 WHERE user_id = $2 RETURNING *',
      ['Rejected', userId]
    );

    const rejectedUser = updateResult.rows[0];

    res.json({
      message: 'User rejected successfully',
      user: {
        user_id: rejectedUser.user_id,
        full_name: rejectedUser.full_name,
        email: rejectedUser.email,
        role: rejectedUser.role,
        status: rejectedUser.status
      }
    });
  } catch (error) {
    console.error('Reject user error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Batch Approve/Reject Multiple Users
router.put('/batch-approve', authenticateToken, async (req, res) => {
  try {
    const { role } = req.user;
    const { user_ids, action } = req.body;

    if (!user_ids || !Array.isArray(user_ids) || user_ids.length === 0) {
      return res.status(400).json({ error: 'user_ids array is required' });
    }
    if (!['approve', 'reject'].includes(action)) {
      return res.status(400).json({ error: 'action must be "approve" or "reject"' });
    }

    const newStatus = action === 'approve' ? 'Active' : 'Rejected';
    const results = { processed: 0, failed: 0, errors: [] };

    // Determine which roles this user can approve
    let allowedTargetRoles = [];
    let coordCourse = null;
    if (role === 'Admin') {
      allowedTargetRoles = ['Coordinator'];
    } else if (role === 'Coordinator') {
      allowedTargetRoles = ['Student', 'Supervisor'];
      // Fetch coordinator's program for course-binding
      const coordResult = await query(
        'SELECT course FROM users WHERE user_id = $1',
        [req.user.user_id]
      );
      coordCourse = coordResult.rows[0]?.course || null;
    } else {
      return res.status(403).json({ error: 'You do not have batch approval permissions' });
    }

    for (const userId of user_ids) {
      try {
        // Verify user exists and is pending
        const userCheck = await query(
          'SELECT role, status, course FROM users WHERE user_id = $1',
          [userId]
        );

        if (userCheck.rows.length === 0) {
          results.failed++;
          results.errors.push(`User ${userId}: not found`);
          continue;
        }

        const targetUser = userCheck.rows[0];
        if (!allowedTargetRoles.includes(targetUser.role)) {
          results.failed++;
          results.errors.push(`User ${userId}: insufficient permissions for role ${targetUser.role}`);
          continue;
        }

        // Program-Bound Check: Skip students from a different program
        if (role === 'Coordinator' && targetUser.role === 'Student' && coordCourse && targetUser.course && coordCourse !== targetUser.course) {
          results.failed++;
          results.errors.push(`User ${userId}: belongs to ${targetUser.course}, your program is ${coordCourse}`);
          continue;
        }

        if (targetUser.status !== 'Pending') {
          results.failed++;
          results.errors.push(`User ${userId}: status is ${targetUser.status}, not Pending`);
          continue;
        }

        await query(
          'UPDATE users SET status = $1 WHERE user_id = $2',
          [newStatus, userId]
        );
        results.processed++;
      } catch (innerErr) {
        results.failed++;
        results.errors.push(`User ${userId}: ${innerErr.message}`);
      }
    }

    res.json({
      message: `Batch ${action} complete: ${results.processed} processed, ${results.failed} failed`,
      ...results
    });
  } catch (error) {
    console.error('Batch approve error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;

