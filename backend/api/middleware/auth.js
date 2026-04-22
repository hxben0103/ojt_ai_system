const jwt = require('jsonwebtoken');

const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET) {
  console.error('❌ FATAL: JWT_SECRET environment variable is not set. Please configure your .env file.');
  process.exit(1);
}

const authenticateToken = (req, res, next) => {
  try {
    const authHeader = req.headers['authorization'] || req.headers.authorization;
    // Check both Authorization header and 'token' query parameter
    const token = (authHeader && authHeader.split(' ')[1]) || req.query.token;

    if (!token) {
      return res.status(401).json({ error: 'No token provided / Access token required' });
    }

    jwt.verify(token, JWT_SECRET, (err, user) => {
      if (err) {
        return res.status(403).json({ error: 'Invalid or expired token' });
      }
      req.user = user;
      next();
    });
  } catch (error) {
    return res.status(401).json({ error: 'Invalid token' });
  }
};

module.exports = authenticateToken;
