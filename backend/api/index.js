process.env.TZ = 'Asia/Manila';
const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const rateLimit = require('express-rate-limit');
const dgram = require('dgram');
require('dotenv').config({ path: './config/env/.env' });

const app = express();
const PORT = process.env.PORT || 3000;

// Enhanced CORS configuration for Flutter Web
const corsOptions = {
  origin: function (origin, callback) {
    // Allow requests with no origin (like mobile apps, Postman, or curl)
    if (!origin) return callback(null, true);

    // Allow ALL localhost origins (any port) - covers Flutter web random ports
    if (origin.includes('localhost') || origin.includes('127.0.0.1')) {
      return callback(null, true);
    }

    // In production, specify allowed origins
    if (process.env.NODE_ENV === 'production') {
      const allowedOrigins = [
        'http://localhost:8080',
        'http://localhost:3000',
        'http://127.0.0.1:8080',
        // Production: Render backend + Flutter web if deployed
        process.env.RENDER_EXTERNAL_URL,         // auto-set by Render
        process.env.FRONTEND_URL,                 // set manually if Flutter web is deployed
      ].filter(Boolean);  // remove undefined entries

      if (allowedOrigins.indexOf(origin) !== -1) {
        callback(null, true);
      } else {
        callback(new Error('Not allowed by CORS'));
      }
    } else {
      // Development: allow all localhost origins
      callback(null, true);
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
};

app.use(cors(corsOptions));
app.use(bodyParser.json({ limit: '15mb' }));
app.use(bodyParser.urlencoded({ extended: true, limit: '15mb' }));

// API Response Time Logging Middleware
app.use('/api', (req, res, next) => {
  const start = Date.now();

  // Log request
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.originalUrl}`);

  // Capture response finish event
  res.on('finish', () => {
    const duration = Date.now() - start;
    const statusColor = res.statusCode >= 500 ? '🔴' :
      res.statusCode >= 400 ? '🟡' : '🟢';

    console.log(
      `${statusColor} [API] ${req.method} ${req.originalUrl} -> ${res.statusCode} (${duration}ms)`
    );
  });

  next();
});

// Import routes
const authRoutes = require('./routes/auth');
const attendanceRoutes = require('./routes/attendance');
const evaluationRoutes = require('./routes/evaluation');
const predictionRoutes = require('./routes/prediction');
const coordinatorAnalyticsRoutes = require('./routes/coordinatorAnalytics');
const reportsRoutes = require('./routes/reports');
const progressReportsRoutes = require('./routes/progressReports');
const chatbotRoutes = require('./routes/chatbot'); // ✅ Chatbot logging & history
const notificationsRoutes = require('./routes/notifications'); // ✅ Notifications

// Import OJT routes with error handling
let ojtRoutes;
try {
  ojtRoutes = require('./routes/ojt');
  console.log('✅ OJT routes loaded successfully');
} catch (error) {
  console.error('❌ Error loading OJT routes:', error);
  throw error;
}

// Import Daily Tasks routes
const dailyTasksRoutes = require('./routes/dailyTasks');
const ojtSitesRoutes = require('./routes/ojtSites');

// ─── Rate Limiters ────────────────────────────────────────────────────────────
// Tight limit on the daily prediction endpoint — it calls Flask + Ollama (heavy)
const predictionDailyLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 30,                   // 30 requests per window per IP
  standardHeaders: 'draft-7', // RateLimit headers per IETF draft (v8+)
  legacyHeaders: false,
  message: {
    error: 'Too many prediction requests. Please wait a few minutes before trying again.',
    retryAfter: '15 minutes'
  }
});

// General limit for all other prediction routes
const predictionLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100,                  // 100 requests per window per IP
  standardHeaders: 'draft-7', // RateLimit headers per IETF draft (v8+)
  legacyHeaders: false,
  message: {
    error: 'Too many requests to the prediction API. Please slow down.',
    retryAfter: '15 minutes'
  }
});

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/attendance', attendanceRoutes);
app.use('/api/evaluation', evaluationRoutes);
app.use('/api/prediction/daily', predictionDailyLimiter); // tight limit first
app.use('/api/prediction', predictionLimiter, predictionRoutes);
app.use('/api/reports', reportsRoutes);
app.use('/api/ojt', ojtRoutes);
app.use('/api/ojt-sites', ojtSitesRoutes);
app.use('/api', dailyTasksRoutes); // Daily tasks routes use /api prefix directly
app.use('/api', coordinatorAnalyticsRoutes); // Coordinator analytics endpoints
app.use('/api/student-reports', progressReportsRoutes);
app.use('/api/chatbot', chatbotRoutes); // ✅ Chatbot logging & history
app.use('/api/notifications', notificationsRoutes); // ✅ Notifications

console.log('✅ All API routes registered');

// Automatic database migration for Program columns
(async () => {
  try {
    const { query } = require('./config/db');
    
    // 1. Add program column to users
    await query(`
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM information_schema.columns 
          WHERE table_name = 'users' AND column_name = 'program'
        ) THEN
          ALTER TABLE users ADD COLUMN program VARCHAR(50) DEFAULT 'Not Specified';
        END IF;
      END $$;
    `);

    // 2. Add program column to competencies
    await query(`
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 FROM information_schema.columns 
          WHERE table_name = 'competencies' AND column_name = 'program'
        ) THEN
          ALTER TABLE competencies ADD COLUMN program VARCHAR(50) DEFAULT 'ALL';
          
          -- Seed specific IT/CS splits based on OJT guidelines
          UPDATE competencies SET program = 'BSIT' WHERE title IN ('Networking', 'Technical Support', 'Information Security Analysis');
          UPDATE competencies SET program = 'BSCS' WHERE title IN ('Software Development', 'Machine Learning Engineering', 'Algorithm Design');
          -- Others like 'UX/UI Design', 'Data Entry' stay 'ALL'
        END IF;
      END $$;
    `);

    console.log('✅ Migrations for Phase 4 (Programs) ensured');
  } catch (err) {
    console.error('❌ Failed to run migrations for Phase 4:', err);
  }
})();

// Health check endpoint
app.get('/api/health', async (req, res) => {
  try {
    const { query } = require('../config/db');
    // Test database connection
    await query('SELECT 1');
    res.json({
      status: 'OK',
      message: 'OJT AI System API is running',
      database: 'connected'
    });
  } catch (error) {
    res.status(503).json({
      status: 'ERROR',
      message: 'OJT AI System API is running but database connection failed',
      database: 'disconnected',
      error: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
});

// 404 handler for unmatched routes
app.use('/api/*', (req, res) => {
  res.status(404).json({
    error: {
      message: `Route not found: ${req.method} ${req.originalUrl}`,
      status: 404
    }
  });
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Error:', err);
  res.status(err.status || 500).json({
    error: {
      message: err.message || 'Internal Server Error',
      status: err.status || 500
    }
  });
});

// Start server - Listen on all interfaces (0.0.0.0) to allow network access
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`📡 API available at http://localhost:${PORT}/api`);
  console.log(`🌐 Network access: Use your computer's IP address to access from other devices`);
  console.log(`   Example: http://192.168.x.x:${PORT}/api`);

  // UDP Auto-Discovery: Broadcast + Respond to probes
  // The Flutter app sends "OJT_DISCOVER" and the backend responds with "OJT_SERVER:<port>"
  const UDP_PORT = 41234;
  const BROADCAST_INTERVAL = 3000;

  try {
    const udpServer = dgram.createSocket({ type: 'udp4', reuseAddr: true });

    udpServer.on('message', (msg, rinfo) => {
      const message = msg.toString().trim();
      // If a Flutter app is searching for us, respond directly to it
      if (message === 'OJT_DISCOVER') {
        const response = Buffer.from(`OJT_SERVER:${PORT}`);
        udpServer.send(response, 0, response.length, rinfo.port, rinfo.address, (err) => {
          if (err) console.warn('⚠️  [UDP] Response error:', err.message);
          else console.log(`📡 [UDP] Responded to probe from ${rinfo.address}:${rinfo.port}`);
        });
      }
    });

    udpServer.bind(UDP_PORT, () => {
      udpServer.setBroadcast(true);
      const message = Buffer.from(`OJT_SERVER:${PORT}`);

      // Also broadcast periodically for simple networks
      setInterval(() => {
        udpServer.send(message, 0, message.length, UDP_PORT, '255.255.255.255', (err) => {
          if (err && err.code !== 'ERR_SOCKET_DGRAM_NOT_RUNNING') {
            // Silently ignore common broadcast errors
          }
        });
      }, BROADCAST_INTERVAL);

      console.log(`📡 [UDP] Listening for discovery probes on port ${UDP_PORT}`);
      console.log(`📡 [UDP] Also broadcasting every ${BROADCAST_INTERVAL / 1000}s`);
      console.log(`📡 [UDP] Flutter app will auto-discover this server on the same Wi-Fi`);
    });

    udpServer.on('error', (err) => {
      console.warn('⚠️  [UDP] Socket error (non-critical):', err.message);
    });
  } catch (err) {
    console.warn('⚠️  [UDP] Could not start discovery (non-critical):', err.message);
  }
});

module.exports = app;