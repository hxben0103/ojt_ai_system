const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const { query } = require('../../config/db');

// Middleware to verify JWT token
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

// Get OJT records - Requires authentication
router.get('/records', authenticateToken, async (req, res) => {
  try {
    console.log('GET /api/ojt/records - Request received', {
      query: req.query,
      user: req.user
    });
    const { student_id, coordinator_id, supervisor_id, status } = req.query;
    
    let sql = `
      SELECT o.*,
             s.full_name AS student_name,
             c.full_name AS coordinator_name,
             sup.full_name AS supervisor_name
      FROM ojt_records o
      JOIN users s ON o.student_id = s.user_id
      JOIN users c ON o.coordinator_id = c.user_id
      JOIN users sup ON o.supervisor_id = sup.user_id
      WHERE 1=1
    `;
    const params = [];
    let paramCount = 1;

    if (student_id) {
      sql += ` AND o.student_id = $${paramCount}`;
      params.push(student_id);
      paramCount++;
    }

    if (coordinator_id) {
      sql += ` AND o.coordinator_id = $${paramCount}`;
      params.push(coordinator_id);
      paramCount++;
    }

    if (supervisor_id) {
      sql += ` AND o.supervisor_id = $${paramCount}`;
      params.push(supervisor_id);
      paramCount++;
    }

    if (status) {
      sql += ` AND o.status = $${paramCount}`;
      params.push(status);
      paramCount++;
    }

    sql += ' ORDER BY o.start_date DESC';

    const result = await query(sql, params);
    res.json({ records: result.rows });
  } catch (error) {
    console.error('Get OJT records error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get OJT record by ID - Requires authentication
router.get('/records/:recordId', authenticateToken, async (req, res) => {
  try {
    const { recordId } = req.params;
    
    const result = await query(
      'SELECT get_ojt_record($1) as record',
      [recordId]
    );

    if (result.rows[0].record) {
      res.json({ record: result.rows[0].record });
    } else {
      res.status(404).json({ error: 'OJT record not found' });
    }
  } catch (error) {
    console.error('Get OJT record error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Create OJT record - Using stored procedure - Requires authentication
router.post('/records', authenticateToken, async (req, res) => {
  try {
    const { 
      student_id, company_name, coordinator_id, supervisor_id, 
      start_date, end_date, required_hours, company_address, company_contact 
    } = req.body;

    if (!student_id || !coordinator_id || !supervisor_id) {
      return res.status(400).json({ 
        error: 'student_id, coordinator_id, and supervisor_id are required' 
      });
    }

    const result = await query(
      'SELECT create_ojt_record($1, $2, $3, $4, $5, $6, $7, $8, $9) as result',
      [
        student_id, company_name, coordinator_id, supervisor_id,
        start_date, end_date || null, required_hours || 300,
        company_address || null, company_contact || null
      ]
    );

    const response = result.rows[0].result;

    if (response.success) {
      // Get the created OJT record
      const recordResult = await query(
        'SELECT get_ojt_record($1) as record',
        [response.record_id]
      );
      
      res.status(201).json({
        message: 'OJT record created successfully',
        record: recordResult.rows[0].record
      });
    } else {
      res.status(400).json({
        error: 'Validation failed',
        errors: response.errors
      });
    }
  } catch (error) {
    console.error('Create OJT record error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Update OJT record - Using stored procedure - Requires authentication
router.put('/records/:recordId', authenticateToken, async (req, res) => {
  try {
    const { recordId } = req.params;
    const { 
      company_name, start_date, end_date, required_hours, 
      status, company_address, company_contact 
    } = req.body;

    const result = await query(
      'SELECT update_ojt_record($1, $2, $3, $4, $5, $6, $7, $8) as result',
      [
        recordId, company_name, start_date, end_date,
        required_hours, status, company_address, company_contact
      ]
    );

    const response = result.rows[0].result;

    if (response.success) {
      const recordResult = await query(
        'SELECT get_ojt_record($1) as record',
        [recordId]
      );
      
      res.json({
        message: 'OJT record updated successfully',
        record: recordResult.rows[0].record
      });
    } else {
      res.status(400).json({
        error: 'Validation failed',
        errors: response.errors
      });
    }
  } catch (error) {
    console.error('Update OJT record error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Delete OJT record - Requires authentication
router.delete('/records/:recordId', authenticateToken, async (req, res) => {
  try {
    const { recordId } = req.params;
    
    const result = await query(
      'SELECT delete_ojt_record($1) as result',
      [recordId]
    );

    const response = result.rows[0].result;

    if (response.success) {
      res.json({ message: 'OJT record deleted successfully' });
    } else {
      res.status(400).json({
        error: 'Failed to delete OJT record',
        errors: response.errors
      });
    }
  } catch (error) {
    console.error('Delete OJT record error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get comprehensive student status - Requires authentication
router.get('/student-status/:studentId', authenticateToken, async (req, res) => {
  try {
    const { studentId } = req.params;

    // Get OJT record with required hours
    const ojtResult = await query(
      `SELECT o.*, s.full_name AS student_name, c.full_name AS coordinator_name, 
              sup.full_name AS supervisor_name
       FROM ojt_records o
       JOIN users s ON o.student_id = s.user_id
       JOIN users c ON o.coordinator_id = c.user_id
       JOIN users sup ON o.supervisor_id = sup.user_id
       -- Treat both Ongoing and Active as current OJT records
       WHERE o.student_id = $1 AND o.status IN ('Ongoing', 'Active')
       ORDER BY o.start_date DESC
       LIMIT 1`,
      [studentId]
    );

    const ojtRecord = ojtResult.rows[0] || null;
    const requiredHours = ojtRecord ? (ojtRecord.required_hours || 300) : 300;

    // Get attendance summary - CRITICAL: Only count approved attendance
    const attendanceResult = await query(
      `SELECT 
         COALESCE(SUM(total_hours), 0) AS total_hours_completed,
         COUNT(DISTINCT date) AS days_present,
         MAX(date) AS last_attendance_date
       FROM attendance
       WHERE student_id = $1 AND status = 'Approved'`,
      [studentId]
    );

    const attendance = attendanceResult.rows[0];
    const completedHours = Math.round(parseFloat(attendance.total_hours_completed) || 0);
    const daysPresent = parseInt(attendance.days_present || 0);
    const lastAttendanceDate = attendance.last_attendance_date;

    // Get latest evaluations (align with actual schema: eval_id, evaluation_period_start/end, date_evaluated)
    const evalResult = await query(
      `SELECT 
         e.eval_id,
         e.total_score,
         e.evaluation_period_start,
         e.evaluation_period_end,
         e.date_evaluated,
         u.role AS evaluator_role,
         u.full_name AS evaluator_name
       FROM evaluations e
       JOIN users u ON e.supervisor_id = u.user_id
       WHERE e.student_id = $1
       ORDER BY e.date_evaluated DESC
       LIMIT 5`,
      [studentId]
    );

    const evaluations = evalResult.rows;

    // Get latest AI insight
    const insightResult = await query(
      `SELECT 
         insight_id,
         model_name,
         insight_type,
         result,
         confidence,
         created_at
       FROM ai_insights
       WHERE student_id = $1
       ORDER BY created_at DESC
       LIMIT 1`,
      [studentId]
    );

    let aiInsight = null;
    if (insightResult.rows.length > 0) {
      const insight = insightResult.rows[0];
      try {
        const resultData = typeof insight.result === 'string' 
          ? JSON.parse(insight.result) 
          : insight.result;
        
        aiInsight = {
          insight_id: insight.insight_id,
          model_name: insight.model_name,
          insight_type: insight.insight_type,
          risk_level: resultData.risk_level || resultData.class_label || null,
          probability: insight.confidence || resultData.probability || null,
          top_reasons: resultData.top_reasons || [],
          recommendation: resultData.recommendation || null,
          created_at: insight.created_at
        };
      } catch (e) {
        console.warn('Failed to parse AI insight result:', e);
      }
    }

    // Calculate progress percentage
    const progressPercentage = requiredHours > 0 
      ? Math.min(100, Math.round((completedHours / requiredHours) * 100))
      : 0;

    // Calculate remaining hours
    const remainingHours = Math.max(0, requiredHours - completedHours);

    // Generate notifications/alerts
    const notifications = [];
    
    // Hours completion alert
    if (progressPercentage >= 90 && progressPercentage < 100) {
      notifications.push({
        type: 'success',
        message: `You're close to completing your required hours! (${completedHours}/${requiredHours} hours, ${remainingHours} remaining)`,
        priority: 'medium'
      });
    } else if (progressPercentage >= 100) {
      notifications.push({
        type: 'success',
        message: `Congratulations! You've completed your required hours (${completedHours}/${requiredHours} hours)`,
        priority: 'low'
      });
    } else if (progressPercentage < 50 && requiredHours > 0) {
      const weeksRemaining = Math.ceil(remainingHours / 40); // Assuming ~40 hours/week
      notifications.push({
        type: 'warning',
        message: `You have ${remainingHours} hours remaining. At current pace, approximately ${weeksRemaining} weeks left.`,
        priority: 'high'
      });
    }

    // Risk level alert
    if (aiInsight && aiInsight.risk_level) {
      if (aiInsight.risk_level === 'HIGH') {
        notifications.push({
          type: 'error',
          message: 'Your risk level is HIGH. Please review your performance and contact your coordinator.',
          priority: 'high'
        });
      } else if (aiInsight.risk_level === 'MEDIUM') {
        notifications.push({
          type: 'warning',
          message: 'Your risk level is MEDIUM. Focus on improving attendance and evaluation scores.',
          priority: 'medium'
        });
      }
    }

    // Last attendance alert
    if (lastAttendanceDate) {
      const lastDate = new Date(lastAttendanceDate);
      const daysSince = Math.floor((new Date() - lastDate) / (1000 * 60 * 60 * 24));
      if (daysSince > 3) {
        notifications.push({
          type: 'warning',
          message: `You haven't logged attendance in ${daysSince} days. Please update your attendance records.`,
          priority: 'medium'
        });
      }
    }

    // Build response
    const status = {
      student_id: parseInt(studentId),
      student_name: ojtRecord?.student_name || null,
      coordinator_name: ojtRecord?.coordinator_name || null,
      supervisor_name: ojtRecord?.supervisor_name || null,
      ojt_record: ojtRecord ? {
        record_id: ojtRecord.record_id,
        company_name: ojtRecord.company_name,
        start_date: ojtRecord.start_date,
        end_date: ojtRecord.end_date,
        status: ojtRecord.status
      } : null,
      hours: {
        completed: completedHours,
        required: requiredHours,
        remaining: remainingHours,
        progress_percentage: progressPercentage
      },
      attendance: {
        days_present: daysPresent,
        last_attendance_date: lastAttendanceDate,
        total_hours_completed: completedHours
      },
      latest_evaluations: evaluations.map(e => ({
        evaluation_id: e.eval_id,
        total_score: parseFloat(e.total_score || 0),
        evaluation_period_start: e.evaluation_period_start,
        evaluation_period_end: e.evaluation_period_end,
        evaluator_role: e.evaluator_role,
        evaluator_name: e.evaluator_name,
        date_evaluated: e.date_evaluated
      })),
      ai_insight: aiInsight,
      notifications: notifications,
      generated_at: new Date().toISOString()
    };

    res.json({ status });
  } catch (error) {
    console.error('Get student status error:', error);
    // Return a safe fallback object instead of crashing the client
    const studentId = parseInt(req.params.studentId, 10) || null;
    res.json({
      status: {
        student_id: studentId,
        student_name: null,
        coordinator_name: null,
        supervisor_name: null,
        ojt_record: null,
        hours: {
          completed: 0,
          required: 300,
          remaining: 300,
          progress_percentage: 0
        },
        attendance: {
          days_present: 0,
          last_attendance_date: null,
          total_hours_completed: 0
        },
        latest_evaluations: [],
        ai_insight: null,
        notifications: [],
        generated_at: new Date().toISOString()
      },
      error: 'Failed to compute student status on server'
    });
  }
});

// Test endpoint to verify route is working (no auth required for testing)
router.get('/test', (req, res) => {
  res.json({ message: 'OJT routes are working!', path: req.path, originalUrl: req.originalUrl });
});

module.exports = router;

