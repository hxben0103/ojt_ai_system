const axios = require('axios');
require('dotenv').config({ path: './config/env/.env' });
const jwt = require('jsonwebtoken');

// 1. Generate an Admin token
const adminPayload = {
  user_id: 1, // Assuming user 1 is an admin
  role: 'Admin',
  email: 'admin@test.com'
};
const token = jwt.sign(adminPayload, process.env.JWT_SECRET);

async function testUpdateCompetency() {
  const competencyId = 11; // Office Work usually
  const newPointValue = 90;
  
  console.log(`🚀 Testing competency update for ID: ${competencyId}...`);
  
  try {
    const response = await axios.put(`http://localhost:5000/api/daily-tasks/competencies/${competencyId}`, {
      pointValue: newPointValue
    }, {
      headers: { Authorization: `Bearer ${token}` }
    });
    
    console.log('✅ Success:', response.data);
    
    if (response.data.competency.pointValue === newPointValue) {
      console.log('✨ Verification PASSED: Point value matches!');
    } else {
      console.log('❌ Verification FAILED: Point value mismatch.');
    }
  } catch (error) {
    console.error('❌ Error testing competency update:', error.response ? error.response.data : error.message);
  }
}

testUpdateCompetency();
