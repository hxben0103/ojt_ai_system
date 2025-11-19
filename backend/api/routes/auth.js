const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { query } = require('../../config/db');

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
        address, required_hours, profile_photo
      )
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
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
        (profile_photo && String(profile_photo).trim() !== '') ? String(profile_photo).trim() : null
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
        process.env.JWT_SECRET || 'your_secret_key',
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

    // Find user
    const result = await query(
      'SELECT * FROM users WHERE email = $1',
      [email]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    const user = result.rows[0];

    // Check password
    const isValidPassword = await bcrypt.compare(password, user.password_hash);

    if (!isValidPassword) {
      return res.status(401).json({ error: 'Invalid email or password' });
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
      process.env.JWT_SECRET || 'your_secret_key',
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
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get User Profile
router.get('/profile', async (req, res) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    
    if (!token) {
      return res.status(401).json({ error: 'No token provided' });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your_secret_key');
    
    const result = await query(
      'SELECT * FROM users WHERE user_id = $1',
      [decoded.user_id]
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
    res.status(401).json({ error: 'Invalid token' });
  }
});

// Get All Users (Admin only)
router.get('/users', async (req, res) => {
  try {
    const result = await query(
      'SELECT user_id, full_name, email, role, status, date_created FROM users ORDER BY date_created DESC'
    );

    res.json({ users: result.rows });
  } catch (error) {
    console.error('Get users error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Middleware to verify JWT token and extract user info
const authenticateToken = (req, res, next) => {
  try {
    const token = req.headers.authorization?.split(' ')[1];
    
    if (!token) {
      return res.status(401).json({ error: 'No token provided' });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your_secret_key');
    req.user = decoded;
    next();
  } catch (error) {
    return res.status(401).json({ error: 'Invalid token' });
  }
};

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
      // Coordinator can see pending Students and Supervisors
      result = await query(
        `SELECT user_id, full_name, email, role, status, student_id, course, 
         age, gender, contact_number, address, date_created 
         FROM users 
         WHERE role IN ('Student', 'Supervisor') AND status = 'Pending' 
         ORDER BY date_created DESC`
      );
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
      // Coordinator approving Student/Supervisor - allowed
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
      // Coordinator rejecting Student/Supervisor - allowed
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

module.exports = router;

