const { Pool } = require('pg');
const dns = require('dns');
require('dotenv').config({ path: './config/env/.env' });

// Use IPv4 first (helps with Supabase ipv6 issues in some environments)
dns.setDefaultResultOrder('ipv4first');

// PostgreSQL Database Connection (Supabase)
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 20, // Increased to 20 for batch AI predictions
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 10000,
  ssl: {
    rejectUnauthorized: false
  }
});

// Test connection and set default settings
pool.on('connect', (client) => {
  console.log('✅ Connected to PostgreSQL database');
  // Set session timezone to Philippines Time (Asia/Manila)
  client.query("SET timezone = 'Asia/Manila'")
    .catch(err => console.error('Error setting session timezone:', err));
});

pool.on('error', (err) => {
  console.error('❌ Database connection error:', err);
});

// Helper function to execute queries
const query = async (text, params) => {
  const start = Date.now();
  try {
    const res = await pool.query(text, params);
    const duration = Date.now() - start;
    if (process.env.NODE_ENV === 'development') {
      const truncatedText = text.length > 200 ? text.substring(0, 197) + '...' : text;
      console.log('Executed query', { text: truncatedText, duration, rows: res.rowCount });
    } else if (duration > 500) {
      console.log('Slow query', { duration, rows: res.rowCount });
    }
    return res;
  } catch (error) {
    console.error('Query error:', error);
    throw error;
  }
};

// Helper function to get a client for transactions
const getClient = async () => {
  const client = await pool.connect();
  const query = client.query.bind(client);
  const release = client.release.bind(client);

  // Set a timeout of 5 seconds for the client
  const timeout = setTimeout(() => {
    console.error('A client has been checked out for more than 5 seconds!');
  }, 5000);

  client.release = () => {
    clearTimeout(timeout);
    return release();
  };

  return client;
};

module.exports = {
  query,
  getClient,
  pool
};

