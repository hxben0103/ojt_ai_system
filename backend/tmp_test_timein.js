const http = require('http');

function testTimeIn() {
  const data = JSON.stringify({
    student_id: 3, 
    segment: "morning_in", 
    time_in: "08:00:00"
  });

  const options = {
    hostname: 'localhost',
    port: 5000,
    path: '/api/attendance/time-in',
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(data),
      'Authorization': 'Bearer test' // dummy token if needed, or we might see a 401/403
    }
  };

  const req = http.request(options, (res) => {
    let body = '';
    res.on('data', chunk => body += chunk);
    res.on('end', () => {
      console.log('Status:', res.statusCode);
      console.log('Response:', body);
    });
  });

  req.on('error', e => console.error(e));
  req.write(data);
  req.end();
}

testTimeIn();
