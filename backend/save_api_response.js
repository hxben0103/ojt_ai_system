const http = require('http');
const fs = require('fs');

http.get('http://localhost:3000/api/attendance?student_id=23', (res) => {
  let data = '';
  res.on('data', (chunk) => {
    data += chunk;
  });
  res.on('end', () => {
    fs.writeFileSync('api_response.json', data);
    console.log('API response saved to api_response.json');
  });
}).on('error', (err) => {
  console.error(err);
});
