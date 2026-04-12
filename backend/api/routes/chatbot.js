const express = require('express');
const router = express.Router();
const { query } = require('../../config/db');
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

/**
 * POST /api/chatbot/log
 * 
 * Logs a chatbot interaction to the chatbot_logs table.
 * This ensures the AI prediction engine can count chatbot engagement
 * as a feature (chatbot_queries_last_30_days).
 * 
 * Body: { query: string, response: string, model_used?: string }
 */
router.post('/log', authenticateToken, async (req, res) => {
  try {
    const { query: userQuery, response, model_used } = req.body;
    const { user_id } = req.user;

    if (!userQuery || !response) {
      return res.status(400).json({
        error: 'Both query and response fields are required'
      });
    }

    // Truncate if extremely long to protect DB
    const truncatedQuery = String(userQuery).substring(0, 2000);
    const truncatedResponse = String(response).substring(0, 5000);
    const modelName = model_used || 'gemma2:2b';

    await query(
      `INSERT INTO chatbot_logs (user_id, query, response, model_used)
       VALUES ($1, $2, $3, $4)`,
      [user_id, truncatedQuery, truncatedResponse, modelName]
    );

    res.status(201).json({ success: true });
  } catch (error) {
    // Non-critical — log but don't break the chatbot experience
    console.error('Chatbot log error:', error.message);
    res.status(500).json({ error: 'Failed to log chatbot interaction' });
  }
});

/**
 * GET /api/chatbot/history
 * 
 * Returns paginated chatbot history for the current user.
 * Used by the AI payload builder to compute chatbot_queries_last_30_days.
 */
router.get('/history', authenticateToken, async (req, res) => {
  try {
    const { user_id } = req.user;
    const limit = Math.min(parseInt(req.query.limit) || 20, 100);

    const result = await query(
      `SELECT chat_id, query, response, model_used, timestamp
       FROM chatbot_logs
       WHERE user_id = $1
       ORDER BY timestamp DESC
       LIMIT $2`,
      [user_id, limit]
    );

    res.json({ history: result.rows });
  } catch (error) {
    console.error('Chatbot history error:', error.message);
    res.status(500).json({ error: 'Internal server error' });
  }
});

/**
 * GET /api/chatbot/stats/:studentId
 * 
 * Returns chatbot engagement stats for AI prediction.
 * Accessible by coordinators, supervisors, and admins.
 */
router.get('/stats/:studentId', authenticateToken, async (req, res) => {
  try {
    const { studentId } = req.params;
    const { role, user_id } = req.user;

    // Students can only view their own stats
    if (role === 'Student' && String(user_id) !== String(studentId)) {
      return res.status(403).json({ error: 'Access denied' });
    }

    const result = await query(
      `SELECT
         COUNT(*) AS total_queries,
         COUNT(CASE WHEN timestamp >= NOW() - INTERVAL '30 days' THEN 1 END) AS queries_last_30_days,
         COUNT(CASE WHEN timestamp >= NOW() - INTERVAL '7 days' THEN 1 END) AS queries_last_7_days,
         MAX(timestamp) AS last_query_at
       FROM chatbot_logs
       WHERE user_id = $1`,
      [studentId]
    );

    const stats = result.rows[0];
    res.json({
      student_id: parseInt(studentId),
      total_chatbot_queries: parseInt(stats.total_queries) || 0,
      chatbot_queries_last_30_days: parseInt(stats.queries_last_30_days) || 0,
      chatbot_queries_last_7_days: parseInt(stats.queries_last_7_days) || 0,
      last_query_at: stats.last_query_at || null
    });
  } catch (error) {
    console.error('Chatbot stats error:', error.message);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
