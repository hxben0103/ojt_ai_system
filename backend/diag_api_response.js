const axios = require('axios');
const jwt = require('jsonwebtoken');
require('dotenv').config({ path: './config/env/.env' });

async function checkStudentStatus(studentId) {
  const token = jwt.sign({ user_id: 1, role: 'Admin' }, process.env.JWT_SECRET || 'your_secret_key');
  
  try {
    console.log(`Checking status for student ${studentId}...`);
    const response = await axios.get(`http://localhost:3000/api/ojt/student-status/${studentId}`, {
      headers: { Authorization: `Bearer ${token}` }
    });
    
    const status = response.data.status;
    console.log('--- AI Insight Object ---');
    console.log(JSON.stringify(status.ai_insight, null, 2));
    
    if (status.ai_insight) {
      console.log('Gemma Explanation Present:', !!status.ai_insight.gemma_explanation);
      if (status.ai_insight.gemma_explanation) {
        console.log('Content Length:', status.ai_insight.gemma_explanation.length);
      }
    } else {
      console.log('AI Insight is NULL');
    }
  } catch (err) {
    console.error('Error:', err.response ? err.response.data : err.message);
  }
}

const targetId = process.argv[2] || '3';
checkStudentStatus(targetId);
