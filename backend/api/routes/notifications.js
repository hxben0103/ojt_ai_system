const express = require('express');
const router = express.Router();
const { query } = require('../../config/db');
const authenticateToken = require('../middleware/auth');

// Auto-initialize notifications table
(async () => {
  try {
    await query(`
      CREATE TABLE IF NOT EXISTS notifications (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(user_id) ON DELETE CASCADE,
        title VARCHAR(255) NOT NULL,
        message TEXT NOT NULL,
        type VARCHAR(50) DEFAULT 'info',
        is_read BOOLEAN DEFAULT false,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      )
    `);
    
    // Add columns if missing (in case table already existed without them)
    // Indexes
    await query(`CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id)`);
    await query(`CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read)`);
    console.log('✅ Notifications table verified');
  } catch (error) {
    console.error('❌ Error initializing notifications table:', error);
  }
})();

// Get all notifications for current user
router.get('/', authenticateToken, async (req, res) => {
  try {
    const { user_id } = req.user;
    
    // Auto-cleanup: Delete notifications older than 30 days
    await query(
      "DELETE FROM notifications WHERE user_id = $1 AND created_at < NOW() - INTERVAL '30 days'",
      [user_id]
    );

    const result = await query(
      'SELECT * FROM notifications WHERE user_id = $1 ORDER BY created_at DESC LIMIT 50',
      [user_id]
    );
    
    res.json({ notifications: result.rows });
  } catch (error) {
    console.error('Get notifications error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get unread count
router.get('/unread-count', authenticateToken, async (req, res) => {
  try {
    const { user_id } = req.user;
    const result = await query(
      'SELECT COUNT(*) as unread_count FROM notifications WHERE user_id = $1 AND is_read = false',
      [user_id]
    );
    res.json({ count: parseInt(result.rows[0].unread_count) });
  } catch (error) {
    console.error('Get unread count error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// ⚠️ L2 FIX: Mark all as read MUST come BEFORE /:id/read
// Express matches routes top-to-bottom; /:id would catch "read-all" as an id otherwise.
router.put('/read-all', authenticateToken, async (req, res) => {
  try {
    const { user_id } = req.user;
    
    await query(
      'UPDATE notifications SET is_read = true WHERE user_id = $1',
      [user_id]
    );
    
    res.json({ success: true, message: 'All notifications marked as read' });
  } catch (error) {
    console.error('Mark all read error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Mark one as read
router.put('/:id/read', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { user_id } = req.user;
    
    const result = await query(
      'UPDATE notifications SET is_read = true WHERE id = $1 AND user_id = $2 RETURNING *',
      [id, user_id]
    );
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Notification not found' });
    }
    
    res.json({ success: true, notification: result.rows[0] });
  } catch (error) {
    console.error('Mark read error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Utility to create a notification (Internal API)
// S7 FIX: Only Coordinators, Supervisors, and Admins can create notifications
router.post('/create', authenticateToken, async (req, res) => {
  try {
    const { role } = req.user;

    // Role check: Only allow Coordinator, Supervisor, or Admin to create notifications
    if (!['Coordinator', 'Supervisor', 'Admin'].includes(role)) {
      return res.status(403).json({ error: 'Access denied. Only coordinators, supervisors, and admins can create notifications.' });
    }

    const { title, message, type, assigned_to } = req.body;
    
    if (!title || !message || !assigned_to) {
      return res.status(400).json({ error: 'Title, message, and assigned_to are required' });
    }
    
    const result = await query(
      'INSERT INTO notifications (user_id, title, message, type) VALUES ($1, $2, $3, $4) RETURNING *',
      [assigned_to, title, message, type || 'info']
    );
    
    res.status(201).json({ success: true, notification: result.rows[0] });
  } catch (error) {
    console.error('Create notification error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
