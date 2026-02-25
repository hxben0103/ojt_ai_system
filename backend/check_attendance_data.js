// Check actual attendance data in database
require('dotenv').config({ path: './config/env/.env' });
const { query } = require('./config/db');

async function checkAttendanceData() {
  console.log('Checking Attendance Data in Database...\n');
  
  try {
    const today = new Date().toISOString().split('T')[0];
    console.log(`Today's date (server time): ${today}\n`);
    
    // Get all attendance records for student IDs 21 and 3
    console.log('=== All Attendance Records for Students 21 and 3 ===\n');
    const allRecords = await query(
      `SELECT 
        a.attendance_id,
        a.student_id,
        u.full_name as student_name,
        a.date,
        a.status,
        a.time_in,
        a.time_out,
        a.total_hours,
        a.created_at
      FROM attendance a
      JOIN users u ON a.student_id = u.user_id
      WHERE a.student_id IN (21, 3)
      ORDER BY a.student_id, a.date DESC
      LIMIT 20`,
      []
    );
    
    if (allRecords.rows.length === 0) {
      console.log('❌ No attendance records found for these students!\n');
    } else {
      console.log(`Found ${allRecords.rows.length} record(s):\n`);
      allRecords.rows.forEach((record, index) => {
        const isToday = record.date.toISOString().split('T')[0] === today;
        const dateStr = record.date.toISOString().split('T')[0];
        console.log(`Record ${index + 1}:`);
        console.log(`  Student ID: ${record.student_id} (${record.student_name})`);
        console.log(`  Date: ${dateStr} ${isToday ? '✅ TODAY' : ''}`);
        console.log(`  Status: ${record.status}`);
        console.log(`  Time In: ${record.time_in || 'N/A'}`);
        console.log(`  Time Out: ${record.time_out || 'N/A'}`);
        console.log(`  Total Hours: ${record.total_hours || 0}`);
        console.log(`  Created At: ${record.created_at || 'N/A'}`);
        console.log('');
      });
    }
    
    // Check what the API endpoint would return
    console.log('=== What API Endpoint Returns ===\n');
    for (const studentId of [21, 3]) {
      const apiResult = await query(
        `SELECT a.*, u.full_name 
         FROM attendance a
         JOIN users u ON a.student_id = u.user_id
         WHERE a.student_id = $1 AND a.date = $2`,
        [studentId, today]
      );
      
      console.log(`Student ID ${studentId}:`);
      if (apiResult.rows.length > 0) {
        const record = apiResult.rows[0];
        console.log(`  ✅ Has attendance for today (${today})`);
        console.log(`  Status: ${record.status}`);
        console.log(`  Expected display: ${getExpectedDisplay(record.status)}`);
      } else {
        // Check if they have attendance for a different date
        const latestRecord = await query(
          `SELECT date, status 
           FROM attendance 
           WHERE student_id = $1 
           ORDER BY date DESC 
           LIMIT 1`,
          [studentId]
        );
        
        if (latestRecord.rows.length > 0) {
          const latestDate = latestRecord.rows[0].date.toISOString().split('T')[0];
          console.log(`  ❌ No attendance for today (${today})`);
          console.log(`  Last attendance: ${latestDate} (Status: ${latestRecord.rows[0].status})`);
          console.log(`  Expected display: "❌ Not on Duty Today"`);
        } else {
          console.log(`  ❌ No attendance records found`);
          console.log(`  Expected display: "❌ Not on Duty Today"`);
        }
      }
      console.log('');
    }
    
    // Check date format in database
    console.log('=== Date Format Check ===\n');
    const dateCheck = await query(
      `SELECT 
        date,
        date::text as date_text,
        CURRENT_DATE as server_date,
        CURRENT_DATE::text as server_date_text
      FROM attendance 
      WHERE student_id IN (21, 3)
      ORDER BY date DESC
      LIMIT 1`,
      []
    );
    
    if (dateCheck.rows.length > 0) {
      console.log('Sample date from database:');
      console.log(`  Date value: ${dateCheck.rows[0].date}`);
      console.log(`  Date text: ${dateCheck.rows[0].date_text}`);
      console.log(`  Server date: ${dateCheck.rows[0].server_date}`);
      console.log(`  Server date text: ${dateCheck.rows[0].server_date_text}`);
    }
    
  } catch (error) {
    console.error('❌ Error:', error.message);
    console.error(error.stack);
  }
  
  process.exit(0);
}

function getExpectedDisplay(status) {
  switch (status) {
    case 'Approved':
      return '"✅ On Duty Today (Approved)" - Green avatar and text';
    case 'Pending':
      return '"⏳ On Duty Today (Pending Approval)" - Orange avatar and text';
    case 'Rejected':
      return '"❌ On Duty Today (Rejected)" - Red avatar and text';
    default:
      return '"✅ On Duty Today" - Blue avatar and text';
  }
}

checkAttendanceData();

