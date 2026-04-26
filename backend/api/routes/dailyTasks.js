const express = require('express');
const router = express.Router();
const { query } = require('../../config/db');
const authenticateToken = require('../middleware/auth');

// =====================================================
// GET /api/competencies
// Returns list of all competencies
// =====================================================
router.get('/competencies', async (req, res) => {
  try {
    const { program } = req.query;
    
    let queryText = 'SELECT competency_id, title, point_value FROM competencies';
    let queryParams = [];
    
    if (program) {
      queryText += ' WHERE program = $1 OR program = \'ALL\'';
      queryParams.push(program);
    }
    
    queryText += ' ORDER BY point_value DESC, title';
    
    const result = await query(queryText, queryParams);

    res.json({
      competencies: result.rows.map(row => ({
        competencyId: row.competency_id,
        title: row.title,
        pointValue: row.point_value
      }))
    });
  } catch (error) {
    console.error('Get competencies error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// =====================================================
// PUT /api/daily-tasks/competencies/:id
// Updates a competency point value (Auth required, Admin only)
// =====================================================
router.put('/competencies/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { pointValue } = req.body;
    const currentUser = req.user;

    // Authorization: Only Admins can update competencies
    if (currentUser.role !== 'Admin' && currentUser.role !== 'admin') {
      return res.status(403).json({ error: 'Access denied: Admin only' });
    }

    if (pointValue === undefined || pointValue === null) {
      return res.status(400).json({ error: 'pointValue is required' });
    }

    const result = await query(
      'UPDATE competencies SET point_value = $1, updated_at = CURRENT_TIMESTAMP WHERE competency_id = $2 RETURNING *',
      [pointValue, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Competency not found' });
    }

    const updated = result.rows[0];
    res.json({
      message: 'Competency updated successfully',
      competency: {
        competencyId: updated.competency_id,
        title: updated.title,
        pointValue: updated.point_value
      }
    });
  } catch (error) {
    console.error('Update competency error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// =====================================================
// GET /api/students/:studentId/daily-tasks
// Returns all daily tasks for a student with competency info
// =====================================================
router.get('/students/:studentId/daily-tasks', authenticateToken, async (req, res) => {
  try {
    const { studentId } = req.params;
    const currentUser = req.user;

    // Authorization: Students can only see their own tasks
    // Supervisors/Coordinators can see tasks for their assigned students
    if (currentUser.role === 'Student' && currentUser.user_id != studentId) {
      return res.status(403).json({ error: 'Access denied' });
    }

    // For supervisors/coordinators, verify they have access to this student
    if (currentUser.role !== 'Student') {
      const accessCheck = await query(
        `SELECT o.record_id 
         FROM ojt_records o 
         WHERE o.student_id = $1 
           AND (o.supervisor_id = $2 OR o.coordinator_id = $2)`,
        [studentId, currentUser.user_id]
      );

      if (accessCheck.rows.length === 0 && currentUser.role !== 'Admin') {
        return res.status(403).json({ error: 'Access denied: Student not assigned to you' });
      }
    }

    const result = await query(
      `SELECT 
         t.task_id,
         t.student_id,
         t.date,
         t.task_description,
         t.hours_worked,
         t.supervisor_id,
         t.status,
         t.remarks,
         t.created_at,
         t.updated_at,
         t.coordinator_comment,
         t.coordinator_comment_at,
         c.competency_id,
         c.title AS competency_title,
         c.point_value AS competency_point_value
       FROM ojt_daily_tasks t
       LEFT JOIN task_competencies tc ON t.task_id = tc.task_id
       LEFT JOIN competencies c ON tc.competency_id = c.competency_id
       WHERE t.student_id = $1
       ORDER BY t.date DESC, t.created_at DESC`,
      [studentId]
    );

    // Group tasks by task_id (since one task can have multiple competencies)
    const taskMap = new Map();

    result.rows.forEach(row => {
      if (!taskMap.has(row.task_id)) {
        taskMap.set(row.task_id, {
          taskId: row.task_id,
          studentId: row.student_id,
          date: row.date,
          taskDescription: row.task_description,
          hoursWorked: parseFloat(row.hours_worked) || 0,
          supervisorId: row.supervisor_id,
          status: row.status,
          remarks: row.remarks,
          createdAt: row.created_at,
          updatedAt: row.updated_at,
          coordinatorComment: row.coordinator_comment,
          coordinatorCommentAt: row.coordinator_comment_at,
          competencies: []
        });
      }

      if (row.competency_id) {
        taskMap.get(row.task_id).competencies.push({
          competencyId: row.competency_id,
          title: row.competency_title,
          pointValue: row.competency_point_value
        });
      }
    });

    res.json({ tasks: Array.from(taskMap.values()) });
  } catch (error) {
    console.error('Get daily tasks error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// =====================================================
// POST /api/students/:studentId/daily-tasks
// Creates a new daily task for a student
// =====================================================
router.post('/students/:studentId/daily-tasks', authenticateToken, async (req, res) => {
  try {
    const { studentId } = req.params;
    const { date, taskDescription, hoursWorked, competencyId } = req.body;
    const currentUser = req.user;

    // Validation
    if (!date || !taskDescription || !competencyId) {
      return res.status(400).json({
        error: 'Missing required fields: date, taskDescription, and competencyId are required'
      });
    }

    // Authorization: Students can only create tasks for themselves
    if (currentUser.role === 'Student' && currentUser.user_id != studentId) {
      return res.status(403).json({ error: 'Access denied' });
    }

    // Verify competency exists
    const competencyCheck = await query(
      'SELECT competency_id FROM competencies WHERE competency_id = $1',
      [competencyId]
    );

    if (competencyCheck.rows.length === 0) {
      return res.status(400).json({ error: 'Invalid competencyId' });
    }

    // STRICT OJT ENROLLMENT CHECK
    let supervisorId = null;
    if (currentUser.role === 'Student') {
      const ojtRecord = await query(
        `SELECT supervisor_id 
         FROM ojt_records 
         WHERE student_id = $1 
         AND status IN ('Active', 'Ongoing')
         AND coordinator_id IS NOT NULL 
         AND supervisor_id IS NOT NULL
         LIMIT 1`,
        [studentId]
      );

      if (ojtRecord.rows.length > 0) {
        supervisorId = ojtRecord.rows[0].supervisor_id;
      } else {
        return res.status(403).json({
          error: 'You cannot perform this action because your OJT setup is incomplete. Coordinator or Supervisor assignment is missing.'
        });
      }
    }

    // Insert task
    const taskResult = await query(
      `INSERT INTO ojt_daily_tasks 
         (student_id, date, task_description, hours_worked, supervisor_id, status)
       VALUES ($1, $2, $3, $4, $5, 'Pending')
       RETURNING *`,
      [studentId, date, taskDescription, hoursWorked || null, supervisorId]
    );


    const task = taskResult.rows[0];

    // Link competency
    await query(
      'INSERT INTO task_competencies (task_id, competency_id) VALUES ($1, $2)',
      [task.task_id, competencyId]
    );

    // Fetch full task with competency info
    const fullTaskResult = await query(
      `SELECT 
         t.*,
         c.competency_id,
         c.title AS competency_title,
         c.point_value AS competency_point_value
       FROM ojt_daily_tasks t
       JOIN task_competencies tc ON t.task_id = tc.task_id
       JOIN competencies c ON tc.competency_id = c.competency_id
       WHERE t.task_id = $1`,
      [task.task_id]
    );

    const taskData = {
      taskId: fullTaskResult.rows[0].task_id,
      studentId: fullTaskResult.rows[0].student_id,
      date: fullTaskResult.rows[0].date,
      taskDescription: fullTaskResult.rows[0].task_description,
      hoursWorked: parseFloat(fullTaskResult.rows[0].hours_worked) || 0,
      supervisorId: fullTaskResult.rows[0].supervisor_id,
      status: fullTaskResult.rows[0].status,
      remarks: fullTaskResult.rows[0].remarks,
      coordinatorComment: fullTaskResult.rows[0].coordinator_comment,
      coordinatorCommentAt: fullTaskResult.rows[0].coordinator_comment_at,
      competency: {
        competencyId: fullTaskResult.rows[0].competency_id,
        title: fullTaskResult.rows[0].competency_title,
        pointValue: fullTaskResult.rows[0].competency_point_value
      }
    };

    res.status(201).json({
      message: 'Daily task created successfully',
      task: taskData
    });
  } catch (error) {
    console.error('Create daily task error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// =====================================================
// PUT /api/daily-tasks/:taskId/status
// Updates task status (Approve/Reject) - Supervisor only
// =====================================================
router.put('/daily-tasks/:taskId/status', authenticateToken, async (req, res) => {
  try {
    const { taskId } = req.params;
    const { status, remarks } = req.body;
    const currentUser = req.user;

    // Validation
    if (!status || !['Approved', 'Rejected', 'Pending'].includes(status)) {
      return res.status(400).json({
        error: 'Invalid status. Must be: Approved, Rejected, or Pending'
      });
    }

    // Authorization: Only supervisors and admins can approve/reject
    if (currentUser.role !== 'Supervisor' && currentUser.role !== 'Admin') {
      return res.status(403).json({ error: 'Only supervisors can approve/reject tasks' });
    }

    // Verify task exists and supervisor has access
    const taskCheck = await query(
      `SELECT t.*, o.supervisor_id 
       FROM ojt_daily_tasks t
       JOIN ojt_records o ON t.student_id = o.student_id
       -- Treat OJT records as active when status is either 'Ongoing' (schema default) or 'Active'
       WHERE t.task_id = $1 AND o.status IN ('Ongoing', 'Active')`,
      [taskId]
    );

    if (taskCheck.rows.length === 0) {
      return res.status(404).json({ error: 'Task not found' });
    }

    const task = taskCheck.rows[0];

    // Verify supervisor access (unless admin)
    if (currentUser.role !== 'Admin' && task.supervisor_id != currentUser.user_id) {
      return res.status(403).json({ error: 'Access denied: Task not assigned to you' });
    }

    // Update task
    const updateResult = await query(
      `UPDATE ojt_daily_tasks 
       SET status = $1, 
           remarks = $2,
           supervisor_id = CASE WHEN supervisor_id IS NULL THEN $3 ELSE supervisor_id END,
           updated_at = CURRENT_TIMESTAMP
       WHERE task_id = $4
       RETURNING *`,
      [status, remarks || null, currentUser.user_id, taskId]
    );

    // Fetch full task with competency info
    const fullTaskResult = await query(
      `SELECT 
         t.*,
         c.competency_id,
         c.title AS competency_title,
         c.point_value AS competency_point_value
       FROM ojt_daily_tasks t
       LEFT JOIN task_competencies tc ON t.task_id = tc.task_id
       LEFT JOIN competencies c ON tc.competency_id = c.competency_id
       WHERE t.task_id = $1`,
      [taskId]
    );

    const competencies = fullTaskResult.rows
      .filter(row => row.competency_id)
      .map(row => ({
        competencyId: row.competency_id,
        title: row.competency_title,
        pointValue: row.competency_point_value
      }));

    const taskData = {
      taskId: fullTaskResult.rows[0].task_id,
      studentId: fullTaskResult.rows[0].student_id,
      date: fullTaskResult.rows[0].date,
      taskDescription: fullTaskResult.rows[0].task_description,
      hoursWorked: parseFloat(fullTaskResult.rows[0].hours_worked) || 0,
      supervisorId: fullTaskResult.rows[0].supervisor_id,
      status: fullTaskResult.rows[0].status,
      remarks: fullTaskResult.rows[0].remarks,
      competencies: competencies
    };

    res.json({
      message: 'Task status updated successfully',
      task: taskData
    });
  } catch (error) {
    console.error('Update task status error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// =====================================================
// GET /api/students/:studentId/competency-summary
// Returns aggregated hours per competency (only approved tasks)
// =====================================================
router.get('/students/:studentId/competency-summary', authenticateToken, async (req, res) => {
  try {
    const { studentId } = req.params;
    const currentUser = req.user;

    // Authorization check
    if (currentUser.role === 'Student' && currentUser.user_id != studentId) {
      return res.status(403).json({ error: 'Access denied' });
    }

    if (currentUser.role !== 'Student') {
      const accessCheck = await query(
        `SELECT o.record_id 
         FROM ojt_records o 
         WHERE o.student_id = $1 
           AND (o.supervisor_id = $2 OR o.coordinator_id = $2)`,
        [studentId, currentUser.user_id]
      );

      if (accessCheck.rows.length === 0 && currentUser.role !== 'Admin') {
        return res.status(403).json({ error: 'Access denied' });
      }
    }

    // Aggregate hours by competency (only approved tasks)
    const result = await query(
      `SELECT 
         c.competency_id,
         c.title,
         c.point_value,
         COALESCE(SUM(t.hours_worked), 0) AS total_hours,
         COUNT(t.task_id) AS task_count
       FROM competencies c
       LEFT JOIN task_competencies tc ON c.competency_id = tc.competency_id
       LEFT JOIN ojt_daily_tasks t ON tc.task_id = t.task_id 
         AND t.student_id = $1 
         AND t.status = 'Approved'
       GROUP BY c.competency_id, c.title, c.point_value
       HAVING COALESCE(SUM(t.hours_worked), 0) > 0 OR COUNT(t.task_id) = 0
       ORDER BY total_hours DESC, c.point_value DESC, c.title`,
      [studentId]
    );

    res.json({
      summary: result.rows.map(row => ({
        competencyId: row.competency_id,
        title: row.title,
        pointValue: row.point_value,
        totalHours: parseFloat(row.total_hours) || 0,
        taskCount: parseInt(row.task_count) || 0
      }))
    });
  } catch (error) {
    console.error('Get competency summary error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// =====================================================
// GET /api/supervisors/:supervisorId/pending-tasks
// Returns all pending tasks for students assigned to a supervisor
// =====================================================
router.get('/supervisors/:supervisorId/pending-tasks', authenticateToken, async (req, res) => {
  try {
    const { supervisorId } = req.params;
    const currentUser = req.user;

    // Authorization: Only the supervisor themselves or admin can access
    if (currentUser.role !== 'Admin' && currentUser.user_id != supervisorId) {
      return res.status(403).json({ error: 'Access denied' });
    }

    const result = await query(
      `SELECT 
         t.task_id,
         t.student_id,
         u.full_name AS student_name,
         t.date,
         t.task_description,
         t.hours_worked,
         t.status,
         t.remarks,
         t.created_at,
         c.competency_id,
         c.title AS competency_title,
         c.point_value AS competency_point_value
       FROM ojt_daily_tasks t
       JOIN users u ON t.student_id = u.user_id
       JOIN ojt_records o ON t.student_id = o.student_id
       LEFT JOIN task_competencies tc ON t.task_id = tc.task_id
       LEFT JOIN competencies c ON tc.competency_id = c.competency_id
       WHERE o.supervisor_id = $1 AND t.status = 'Pending'
       ORDER BY t.date DESC, t.created_at DESC
       LIMIT 50`,
      [supervisorId]
    );

    // Group by task_id
    const taskMap = new Map();

    result.rows.forEach(row => {
      if (!taskMap.has(row.task_id)) {
        taskMap.set(row.task_id, {
          taskId: row.task_id,
          studentId: row.student_id,
          studentName: row.student_name,
          date: row.date,
          taskDescription: row.task_description,
          hoursWorked: parseFloat(row.hours_worked) || 0,
          status: row.status,
          remarks: row.remarks,
          createdAt: row.created_at,
          competencies: []
        });
      }

      if (row.competency_id) {
        taskMap.get(row.task_id).competencies.push({
          competencyId: row.competency_id,
          title: row.competency_title,
          pointValue: row.competency_point_value
        });
      }
    });

    res.json({ tasks: Array.from(taskMap.values()) });
  } catch (error) {
    console.error('Get pending tasks error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// =====================================================
// PUT /api/daily-tasks/batch-approve
// Batch approve/reject multiple tasks at once - Supervisor only
// =====================================================
router.put('/daily-tasks/batch-approve', authenticateToken, async (req, res) => {
  try {
    const { task_ids, status, remarks } = req.body;
    const currentUser = req.user;

    if (!task_ids || !Array.isArray(task_ids) || task_ids.length === 0) {
      return res.status(400).json({ error: 'task_ids array is required and must not be empty' });
    }

    if (!status || !['Approved', 'Rejected'].includes(status)) {
      return res.status(400).json({ error: 'status must be Approved or Rejected' });
    }

    if (currentUser.role !== 'Supervisor' && currentUser.role !== 'Admin') {
      return res.status(403).json({ error: 'Only supervisors can approve/reject tasks' });
    }

    // Verify all tasks belong to this supervisor's students
    const verifyResult = await query(
      `SELECT t.task_id FROM ojt_daily_tasks t
       JOIN ojt_records o ON t.student_id = o.student_id
       WHERE t.task_id = ANY($1::int[])
         AND o.supervisor_id = $2
         AND o.status IN ('Ongoing', 'Active')`,
      [task_ids, currentUser.user_id]
    );

    const authorizedIds = verifyResult.rows.map(r => r.task_id);
    if (authorizedIds.length === 0) {
      return res.status(403).json({ error: 'No authorized tasks found for batch update' });
    }

    await query(
      `UPDATE ojt_daily_tasks
       SET status = $1, remarks = $2, updated_at = CURRENT_TIMESTAMP
       WHERE task_id = ANY($3::int[])`,
      [status, remarks || null, authorizedIds]
    );

    res.json({
      message: `${authorizedIds.length} task(s) ${status.toLowerCase()} successfully`,
      updated_count: authorizedIds.length,
      updated_ids: authorizedIds
    });
  } catch (error) {
    console.error('Batch approve error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;

