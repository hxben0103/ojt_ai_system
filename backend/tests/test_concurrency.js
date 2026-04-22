const axios = require('axios');

async function testConcurrency() {
    const studentId = 1; // Change to a valid test student ID
    const date = '2026-04-17';
    const segment = 'MORNING_IN';
    const url = 'http://localhost:3000/api/attendance/time-in';
    
    // You'll need a valid JWT token here
    const token = 'YOUR_JWT_TOKEN'; 

    console.log('--- Testing Concurrency ---');
    
    const requests = [
        axios.post(url, { student_id: studentId, date, segment }, { headers: { Authorization: `Bearer ${token}` }}),
        axios.post(url, { student_id: studentId, date, segment }, { headers: { Authorization: `Bearer ${token}` }})
    ];

    try {
        const results = await Promise.allSettled(requests);
        results.forEach((r, i) => {
            if (r.status === 'fulfilled') {
                console.log(`Req ${i+1}: Success - Status ${r.value.status}`);
            } else {
                console.log(`Req ${i+1}: Failed - ${r.reason.response?.data?.error || r.reason.message}`);
            }
        });
    } catch (e) {
        console.error('Test script error:', e.message);
    }
}

// Note: This script requires a running server and valid token.
// Since I can't easily get a long-lived token for an arbitrary student here,
// I'll rely on the logic check and the DB constraint verification.
