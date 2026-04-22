const { Pool } = require('pg');
require('dotenv').config({ path: './config/env/.env' });

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }
});

async function runDiagnostic() {
  console.log('--- 🛡️ Attendance Integrity Diagnostic ---');
  try {
    const res = await pool.query(`
      SELECT a.*, u.full_name 
      FROM attendance a 
      JOIN users u ON a.student_id = u.user_id 
      ORDER BY a.date DESC 
      LIMIT 100
    `);

    const rows = res.rows;
    if (rows.length === 0) {
      console.log('No attendance records found to analyze.');
      return;
    }

    const issues = [];
    const secondsTable = {};

    rows.forEach(row => {
      const parse = (t) => {
        if (!t || t === '-') return null;
        const parts = t.split(':');
        return parseInt(parts[0]) * 3600 + parseInt(parts[1]) * 60 + (parts.length > 2 ? parseInt(parts[2]) : 0);
      };

      const in1 = parse(row.morning_in);
      const out1 = parse(row.morning_out);
      const in2 = parse(row.afternoon_in);
      const out2 = parse(row.afternoon_out);
      const in3 = parse(row.overtime_in);
      const out3 = parse(row.overtime_out);

      // Logical Sequence Checks
      if (in1 && out1 && out1 <= in1) issues.push(`AM Sequence Error: ${row.full_name} (${row.date}) - In: ${row.morning_in}, Out: ${row.morning_out}`);
      if (in2 && out2 && out2 <= in2) issues.push(`PM Sequence Error: ${row.full_name} (${row.date}) - In: ${row.afternoon_in}, Out: ${row.afternoon_out}`);
      if (in3 && out3 && out3 <= in3) issues.push(`OT Sequence Error: ${row.full_name} (${row.date}) - In: ${row.overtime_in}, Out: ${row.overtime_out}`);
      if (out1 && in2 && in2 < out1) issues.push(`Overlap Error: ${row.full_name} (${row.date}) - PM In (${row.afternoon_in}) < AM Out (${row.morning_out})`);

      // Timing Distribution (Stochasticity check)
      [row.morning_in, row.morning_out, row.afternoon_in, row.afternoon_out, row.overtime_in, row.overtime_out].forEach(t => {
        if (t && t !== '-') {
          const parts = t.split(':');
          const sec = parts.length > 1 ? (parts.length > 2 ? parts[2] : '00') : null;
          if (sec !== null) {
            secondsTable[sec] = (secondsTable[sec] || 0) + 1;
          }
        }
      });
    });

    console.log(`Analyzed last ${rows.length} attendance records.\n`);

    if (issues.length === 0) {
      console.log('✅ LOGIC CHECK: PASS');
      console.log('No sequence errors, overlapping time segments, or zero-duration logs found.');
    } else {
      console.log('❌ LOGIC ERRORS DETECTED:');
      issues.forEach(i => console.log(`   ${i}`));
    }

    console.log('\n--- 📊 AI Integrity Pulse ---');
    const sortedSecs = Object.entries(secondsTable).sort((a, b) => b[1] - a[1]);
    if (sortedSecs.length > 0) {
      const [topSec, count] = sortedSecs[0];
      const ratio = count / (rows.length * 2); // Conservative estimate
      console.log(`Mode second clumping: :${topSec} (${count} occurrences)`);
      
      if (ratio > 0.8) {
        console.log('⚠️ ALERT: Extreme clumping detected. Submissions appear automated or manually normalized.');
      } else if (ratio > 0.4) {
        console.log('⚠️ WARNING: Moderate clumping detected. May indicate patterned behavior.');
      } else {
        console.log('✅ STATUS: Natural stochasticity. Logistics appear human-generated.');
      }
    } else {
      console.log('Insufficient timestamp data for pulse analysis.');
    }

  } catch (err) {
    console.error('Diagnostic failed:', err.message);
  } finally {
    await pool.end();
  }
}

runDiagnostic();
