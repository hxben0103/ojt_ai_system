require('dotenv').config({ path: './config/env/.env' });
const { query } = require('./config/db');

async function run() {
    console.log('\n===== COORDINATOR DIAGNOSTIC =====\n');

    // 1. All users with coordinator role
    const coords = await query(`
    SELECT user_id, email, full_name, role, is_approved
    FROM users
    WHERE role ILIKE '%coordinator%'
  `);
    console.log('[1] Coordinators in DB:');
    if (coords.rows.length === 0) {
        console.log('  ❌ NONE FOUND');
    } else {
        coords.rows.forEach(c => console.log(`  user_id=${c.user_id} | ${c.full_name} | ${c.email} | approved=${c.is_approved}`));
    }

    // 2. All OJT records - show coordinator_id for each
    const records = await query(`
    SELECT o.record_id, o.student_id, o.coordinator_id, o.supervisor_id, o.status,
           s.full_name AS student_name,
           c.full_name AS coordinator_name,
           sup.full_name AS supervisor_name
    FROM ojt_records o
    LEFT JOIN users s ON o.student_id = s.user_id
    LEFT JOIN users c ON o.coordinator_id = c.user_id
    LEFT JOIN users sup ON o.supervisor_id = sup.user_id
    ORDER BY o.record_id
  `);
    console.log(`\n[2] OJT Records (total: ${records.rows.length}):`);
    if (records.rows.length === 0) {
        console.log('  ❌ NO OJT RECORDS AT ALL');
    } else {
        records.rows.forEach(r => {
            console.log(`  record_id=${r.record_id} | student="${r.student_name}" (id=${r.student_id}) | coordinator="${r.coordinator_name}" (id=${r.coordinator_id}) | supervisor="${r.supervisor_name}" (id=${r.supervisor_id}) | status=${r.status}`);
        });
    }

    // 3. Match - do OJT records coordinator_id match any coordinator user_id?
    console.log('\n[3] Coordinator ID Match Check:');
    const coordIds = new Set(coords.rows.map(c => c.user_id));
    records.rows.forEach(r => {
        const matched = coordIds.has(r.coordinator_id);
        console.log(`  record_id=${r.record_id} | coordinator_id=${r.coordinator_id} -> match=${matched ? '✅ YES' : '❌ NO - MISMATCH!'}`);
    });

    // 4. What status values exist?
    const statuses = await query(`SELECT DISTINCT status, COUNT(*) FROM ojt_records GROUP BY status`);
    console.log('\n[4] OJT Status Values in DB:');
    statuses.rows.forEach(s => console.log(`  "${s.status}" = ${s.count} record(s)`));

    // 5. Attendance records summary (any student)
    const att = await query(`
    SELECT student_id, status, COUNT(*) as cnt
    FROM attendance
    GROUP BY student_id, status
    ORDER BY student_id
  `);
    console.log('\n[5] Attendance records in DB (grouped):');
    if (att.rows.length === 0) {
        console.log('  ❌ NO ATTENDANCE RECORDS AT ALL');
    } else {
        att.rows.forEach(a => console.log(`  student_id=${a.student_id} | status=${a.status} | count=${a.cnt}`));
    }

    // 6. users table - all roles
    const roles = await query(`SELECT role, COUNT(*) FROM users GROUP BY role ORDER BY role`);
    console.log('\n[6] Users by role:');
    roles.rows.forEach(r => console.log(`  "${r.role}" = ${r.count}`));

    console.log('\n===== END DIAGNOSTIC =====\n');
    process.exit(0);
}

run().catch(e => { console.error('FATAL:', e.message); process.exit(1); });
