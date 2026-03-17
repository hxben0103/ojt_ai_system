const axios = require('axios');
const { query } = require('./config/db');

async function testPrediction() {
  try {
    const studentResult = await query("SELECT user_id FROM users WHERE full_name LIKE '%Star%' LIMIT 1");
    if (studentResult.rows.length === 0) {
      console.log('Student not found');
      return;
    }
    const studentId = studentResult.rows[0].user_id;
    console.log(`Testing prediction for student ID: ${studentId}`);

    const response = await axios.get(`http://localhost:3000/api/prediction/daily/${studentId}`, {
      headers: {
        'Authorization': 'Bearer ' + process.env.TEST_TOKEN // I need a token or bypass auth
      }
    });
    console.log(JSON.stringify(response.data, null, 2));
  } catch (e) {
    console.error('Test failed:', e.message);
    if (e.response) {
        console.error('Response data:', JSON.stringify(e.response.data, null, 2));
    }
  }
}

// Or just call the internal logic
async function testInternal() {
    // Mock the req/res for testing the internal logic if needed
}
