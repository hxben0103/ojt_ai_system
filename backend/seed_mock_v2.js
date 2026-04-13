// ============================================================
// SEED MOCK DATA v2  –  Real Filipino names
// Coordinator: momo (mark jarantilla, id=22)
// Supervisor : loloy (loyloy, id=6)
// Period     : 2026-03-20  →  2026-04-10 (weekdays only)
// 1 student has FAKE GPS flags
// ============================================================
const BASE = 'https://vykprjzttyjpnptzbinl.supabase.co/rest/v1';
const KEY  = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ5a3Byanp0dHlqcG5wdHpiaW5sIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjAzMTE4MSwiZXhwIjoyMDg3NjA3MTgxfQ.9htyC9wNZTkxWPLhjdlqZ-rmmefztsq5Av63wj4ysvM';
const H = { 'apikey': KEY, 'Authorization': 'Bearer ' + KEY, 'Content-Type': 'application/json', 'Prefer': 'return=representation' };

async function post(ep, data) {
  const r = await fetch(BASE + '/' + ep, { method: 'POST', headers: H, body: JSON.stringify(data) });
  const t = await r.text();
  if (!r.ok && r.status !== 409) console.error('ERR ' + ep + ': ' + r.status + ' ' + t.substring(0, 300));
  return r.ok ? JSON.parse(t) : null;
}
async function get(ep) {
  const r = await fetch(BASE + '/' + ep, { headers: { 'apikey': KEY, 'Authorization': 'Bearer ' + KEY } });
  return r.ok ? r.json() : [];
}

// ── Constants ──
const COORD_ID = 22;   // momo  (mark jarantilla)
const SUPER_ID = 6;    // loloy (loyloy)
const SITE_LAT = 10.3157;
const SITE_LNG = 123.8854;
const rand  = (a, b) => a + Math.random() * (b - a);
const ri    = (a, b) => Math.floor(rand(a, b + 1));
const pick  = (arr)  => arr[ri(0, arr.length - 1)];

// ── Students  (realistic Filipino names) ──
const students = [
  { full_name: 'Angelica Mae Villanueva',  email: 'angelica.villanueva@student.cit.edu',  student_id: '2022-1001', age: 21, gender: 'Female', contact_number: '09171234567', address: 'Cebu City'       },
  { full_name: 'John Patrick Mendoza',     email: 'johnpatrick.mendoza@student.cit.edu',  student_id: '2022-1002', age: 22, gender: 'Male',   contact_number: '09182345678', address: 'Mandaue City'    },
  { full_name: 'Christine Joy Bautista',   email: 'christinejoy.bautista@student.cit.edu',student_id: '2022-1003', age: 20, gender: 'Female', contact_number: '09193456789', address: 'Lapu-Lapu City'  },
  { full_name: 'Marc Andrei Dela Peña',    email: 'marcandrei.delapena@student.cit.edu',  student_id: '2022-1004', age: 23, gender: 'Male',   contact_number: '09204567890', address: 'Talisay City'    },
  { full_name: 'Rachelle Ann Soriano',     email: 'rachelleann.soriano@student.cit.edu',  student_id: '2022-1005', age: 21, gender: 'Female', contact_number: '09215678901', address: 'Minglanilla'     },
  { full_name: 'Kurt Daniel Espinosa',     email: 'kurtdaniel.espinosa@student.cit.edu',  student_id: '2022-1006', age: 22, gender: 'Male',   contact_number: '09226789012', address: 'Consolacion'     },
  { full_name: 'Jessa Marie Castillo',     email: 'jessamarie.castillo@student.cit.edu',  student_id: '2022-1007', age: 20, gender: 'Female', contact_number: '09237890123', address: 'Naga City'       },
  { full_name: 'Ralph Lester Navarro',     email: 'ralphlester.navarro@student.cit.edu',  student_id: '2022-1008', age: 21, gender: 'Male',   contact_number: '09248901234', address: 'Carcar City'     },
  { full_name: 'Kimberly Grace Reyes',     email: 'kimberlygrace.reyes@student.cit.edu',  student_id: '2022-1009', age: 22, gender: 'Female', contact_number: '09259012345', address: 'Liloan'          },
  { full_name: 'Adrian James Torres',      email: 'adrianjames.torres@student.cit.edu',   student_id: '2022-1010', age: 23, gender: 'Male',   contact_number: '09260123456', address: 'Cordova'         },
];

// Profile for each student (index maps to students[])
// 'fake_gps' = the student who spoofs location
const profiles = [
  'excellent',      // 0 – Angelica
  'great',          // 1 – John Patrick
  'good',           // 2 – Christine Joy
  'average_late',   // 3 – Marc Andrei (sometimes late)
  'excellent',      // 4 – Rachelle Ann
  'great',          // 5 – Kurt Daniel
  'fake_gps',       // 6 – Jessa Marie  ← FAKE GPS STUDENT
  'good',           // 7 – Ralph Lester
  'good_absent',    // 8 – Kimberly Grace (few absences)
  'average_late',   // 9 – Adrian James
];

// Days Kimberly is absent
const absentDates = ['2026-03-25', '2026-03-31', '2026-04-07'];

// ── Task descriptions per competency area (4 weeks) ──
const taskPool = [
  // 0 – Software Development (competency 1)
  ['Set up local dev environment and cloned main repo','Implemented REST API endpoints for student module','Built unit tests for authentication service','Refactored codebase and fixed critical bugs'],
  // 1 – UI/UX Design (competency 4)
  ['Created wireframes for student dashboard','Designed high-fidelity mockups in Figma','Implemented responsive CSS for mobile layouts','Conducted usability testing and iterated designs'],
  // 2 – Data Analysis (competency 8)
  ['Cleaned and preprocessed attendance datasets','Generated statistical reports on student performance','Built data visualizations using Chart.js','Optimized SQL queries for reporting module'],
  // 3 – Technical Support (competency 7)
  ['Hardware inventory and asset tagging','Resolved IT support tickets for office staff','Performed software updates on 15 workstations','Troubleshot network connectivity issues'],
  // 4 – Software Development (competency 1)
  ['Implemented JWT-based authentication','Developed file upload module with validation','Built real-time notification system','Code review sessions and deployment prep'],
  // 5 – Networking (competency 6)
  ['Configured managed switches and VLANs','Set up firewall rules and access control','Monitored network traffic with Wireshark','Deployed network monitoring dashboard'],
  // 6 – Machine Learning (competency 2)
  ['Collected and labeled training data','Trained classification model with scikit-learn','Evaluated model accuracy and tuned hyperparams','Integrated ML predictions into web dashboard'],
  // 7 – Information Security (competency 5)
  ['Performed vulnerability assessment on web app','Reviewed and updated access control policies','Conducted phishing awareness training','Documented incident response procedures'],
  // 8 – Customer Service (competency 9)
  ['Handled customer inquiries via ticketing system','Drafted knowledge-base articles for common issues','Escalated complex technical issues to senior staff','Compiled customer satisfaction reports'],
  // 9 – Data Entry (competency 10)
  ['Encoded student records into management system','Verified and corrected data inconsistencies','Generated weekly compliance reports','Organized digital filing system for records'],
];

const compMap = [1, 4, 8, 7, 1, 6, 2, 5, 9, 10]; // maps student idx → competency_id

// ==================== MAIN ====================
async function main() {
  console.log('╔══════════════════════════════════════════╗');
  console.log('║   OJT MOCK DATA SEED v2  –  10 Students ║');
  console.log('║   Coordinator: momo (id:22)              ║');
  console.log('║   Supervisor : loloy (id:6)              ║');
  console.log('╚══════════════════════════════════════════╝\n');

  // ─── STEP 1: Create Students ───
  console.log('=== STEP 1: Create 10 BSCS Students ===');
  const ids = {};
  for (const s of students) {
    let ex = await get('users?email=eq.' + encodeURIComponent(s.email) + '&select=user_id');
    if (ex.length > 0) {
      ids[s.email] = ex[0].user_id;
      console.log('  ✓ exists: ' + s.full_name + ' → id=' + ex[0].user_id);
      continue;
    }
    let r = await post('users', {
      ...s,
      password_hash: '$2b$10$QJXZ9K1LhV8v8o6Y7nD3zO5p8q2w4E6y8I0u2W4q6E8y0I2u4W6q',
      role: 'Student',
      status: 'Active',
      course: 'BSCS',
      required_hours: 300
    });
    if (r && r[0]) {
      ids[s.email] = r[0].user_id;
      console.log('  ✚ created: ' + s.full_name + ' → id=' + r[0].user_id);
    }
  }

  // ─── STEP 2: OJT Site ───
  console.log('\n=== STEP 2: OJT Site ===');
  let sites = await get('ojt_sites?name=eq.' + encodeURIComponent('Nexus Digital Solutions Office') + '&select=id');
  if (sites.length === 0) {
    await post('ojt_sites', {
      name: 'Nexus Digital Solutions Office',
      latitude: SITE_LAT,
      longitude: SITE_LNG,
      radius_meters: 100,
      company_name: 'Nexus Digital Solutions Corp.'
    });
    console.log('  ✚ created OJT site');
  } else {
    console.log('  ✓ OJT site exists');
  }

  // ─── STEP 3: OJT Records ───
  console.log('\n=== STEP 3: OJT Records → coordinator momo (22), supervisor loloy (6) ===');
  for (const s of students) {
    const sid = ids[s.email];
    if (!sid) continue;
    let ex = await get('ojt_records?student_id=eq.' + sid + '&select=record_id');
    if (ex.length > 0) {
      console.log('  ✓ exists: ' + s.full_name);
      continue;
    }
    await post('ojt_records', {
      student_id: sid,
      company_name: 'Nexus Digital Solutions Corp.',
      coordinator_id: COORD_ID,
      supervisor_id: SUPER_ID,
      start_date: '2026-03-20',
      end_date: '2026-06-20',
      status: 'Ongoing',
      required_hours: 300,
      company_address: 'Cebu IT Park, Apas, Cebu City',
      company_contact: '032-2345678'
    });
    console.log('  ✚ created: ' + s.full_name);
  }

  // ─── STEP 4: Attendance  (Mar 20 → Apr 10, weekdays) ───
  console.log('\n=== STEP 4: Attendance (Mar 20 – Apr 10) ===');
  let attBatch = [];
  let d = new Date('2026-03-20');
  const end = new Date('2026-04-10');

  while (d <= end) {
    const dow = d.getDay();
    if (dow !== 0 && dow !== 6) {  // skip weekends
      const ds = d.toISOString().split('T')[0];
      for (let i = 0; i < students.length; i++) {
        const sid = ids[students[i].email];
        if (!sid) continue;
        const p = profiles[i];

        // Skip absent days
        if (p === 'good_absent' && absentDates.includes(ds)) continue;

        let mi, mo = '12:00:00', ai = '13:00:00', ao = '17:00:00';
        let st, vf, vb, lat, lng, acc, dist, ig, ts, tf, vs;

        switch (p) {
          case 'excellent':
            mi = `07:${ri(50,58)}:00`;
            st = 'Approved'; vf = true; vb = SUPER_ID;
            lat = SITE_LAT + rand(-0.0001, 0.0001);
            lng = SITE_LNG + rand(-0.0001, 0.0001);
            acc = rand(4, 12); dist = rand(3, 20);
            ig = true; ts = ri(96, 100);
            tf = 'TRUSTED'; vs = 'AUTO_VERIFIED';
            break;

          case 'great':
            mi = `07:${ri(48,56)}:00`;
            st = 'Approved'; vf = true; vb = SUPER_ID;
            lat = SITE_LAT + rand(-0.00015, 0.00015);
            lng = SITE_LNG + rand(-0.00015, 0.00015);
            acc = rand(5, 16); dist = rand(5, 35);
            ig = true; ts = ri(92, 100);
            tf = 'TRUSTED'; vs = 'AUTO_VERIFIED';
            break;

          case 'good':
            mi = `07:${ri(55,59)}:00`;
            st = 'Approved'; vf = true; vb = SUPER_ID;
            lat = SITE_LAT + rand(-0.0001, 0.0001);
            lng = SITE_LNG + rand(-0.0001, 0.0001);
            acc = rand(6, 18); dist = rand(8, 40);
            ig = true; ts = ri(88, 98);
            tf = 'TRUSTED'; vs = 'AUTO_VERIFIED';
            break;

          case 'average_late':
            // late on Mon/Wed/Fri, on-time Tue/Thu
            if (dow === 1 || dow === 3 || dow === 5) {
              mi = `08:${ri(10,35)}:00`;
            } else {
              mi = `07:${ri(55,59)}:00`;
            }
            st = 'Approved'; vf = true; vb = SUPER_ID;
            lat = SITE_LAT + rand(-0.00015, 0.00015);
            lng = SITE_LNG + rand(-0.00015, 0.00015);
            acc = rand(8, 22); dist = rand(10, 50);
            ig = true; ts = ri(78, 94);
            tf = 'TRUSTED'; vs = 'AUTO_VERIFIED';
            break;

          case 'good_absent':
            mi = `07:${ri(56,59)}:00`;
            st = 'Approved'; vf = true; vb = SUPER_ID;
            lat = SITE_LAT + rand(-0.0001, 0.0001);
            lng = SITE_LNG + rand(-0.0001, 0.0001);
            acc = rand(5, 14); dist = rand(5, 28);
            ig = true; ts = ri(90, 99);
            tf = 'TRUSTED'; vs = 'AUTO_VERIFIED';
            break;

          case 'fake_gps':
            mi = '08:05:00';
            // Rejected on Mon & Thu, Approved otherwise
            if (dow === 1 || dow === 4) {
              st = 'Rejected'; vf = false; vb = null;
            } else {
              st = 'Approved'; vf = true; vb = SUPER_ID;
            }
            // Spoofed location – far from site
            if (dow === 2 || dow === 5) {
              lat = SITE_LAT + 0.018; lng = SITE_LNG - 0.014; dist = rand(1800, 2200);
            } else if (dow === 3) {
              lat = SITE_LAT - 0.009; lng = SITE_LNG + 0.012; dist = rand(900, 1200);
            } else {
              lat = SITE_LAT + 0.006; lng = SITE_LNG - 0.005; dist = rand(500, 700);
            }
            acc = rand(600, 2500);
            ig = false; ts = ri(8, 30);
            tf = 'MOCK_LOCATION,HIGH_ACCURACY_ERROR,LOCATION_JUMP';
            vs = 'FLAGGED_FAKE_GPS';
            break;
        }

        attBatch.push({
          student_id: sid,
          date: ds,
          morning_in: mi,
          morning_out: mo,
          afternoon_in: ai,
          afternoon_out: ao,
          status: st,
          verified: vf,
          verified_by: vb,
          checkin_lat: Math.round(lat * 1e5) / 1e5,
          checkin_lng: Math.round(lng * 1e5) / 1e5,
          accuracy_m: Math.round(acc * 10) / 10,
          distance_m: Math.round(dist * 10) / 10,
          inside_geofence: ig,
          trust_score: ts,
          trust_flags: tf,
          verification_status: vs
        });
      }
    }
    d.setDate(d.getDate() + 1);
  }

  // Insert in batches of 15
  let ac = 0;
  for (let i = 0; i < attBatch.length; i += 15) {
    let r = await post('attendance', attBatch.slice(i, i + 15));
    if (r) ac += r.length;
  }
  console.log('  ✚ inserted: ' + ac + ' attendance records (expected ~147)');

  // ─── STEP 5: Daily Tasks ───
  console.log('\n=== STEP 5: Daily Tasks ===');
  let taskBatch = [];
  d = new Date('2026-03-20');
  while (d <= end) {
    const dow = d.getDay();
    if (dow !== 0 && dow !== 6) {
      const ds = d.toISOString().split('T')[0];
      const wk = Math.min(3, Math.floor((d - new Date('2026-03-20')) / (7 * 864e5)));
      for (let i = 0; i < students.length; i++) {
        const sid = ids[students[i].email];
        if (!sid) continue;
        const p = profiles[i];

        // skip absent
        if (p === 'good_absent' && absentDates.includes(ds)) continue;

        let taskStatus, rm, hw = 8;

        if (p === 'fake_gps' && (dow === 1 || dow === 4)) {
          taskStatus = 'Rejected'; rm = 'GPS location flagged — attendance rejected'; hw = 0;
        } else if (p === 'average_late' && (dow === 1 || dow === 3 || dow === 5)) {
          taskStatus = 'Approved'; rm = 'Arrived late but completed tasks'; hw = 7;
        } else {
          taskStatus = 'Approved';
          if (p === 'excellent') rm = 'Outstanding work — exceeded expectations';
          else if (p === 'great') rm = 'Excellent quality output';
          else if (p === 'good') rm = 'Solid work, meets expectations';
          else if (p === 'good_absent') rm = 'Good performance when present';
          else if (p === 'fake_gps') rm = 'Completed assigned tasks';
          else rm = 'Task completed satisfactorily';
        }

        taskBatch.push({
          student_id: sid,
          date: ds,
          task_description: taskPool[i][wk],
          hours_worked: hw,
          supervisor_id: SUPER_ID,
          status: taskStatus,
          remarks: rm
        });
      }
    }
    d.setDate(d.getDate() + 1);
  }

  let tc = 0;
  for (let i = 0; i < taskBatch.length; i += 15) {
    let r = await post('ojt_daily_tasks', taskBatch.slice(i, i + 15));
    if (r) tc += r.length;
  }
  console.log('  ✚ inserted: ' + tc + ' daily tasks');

  // ─── STEP 6: Task-Competency Links ───
  console.log('\n=== STEP 6: Task-Competency Links ===');
  for (let i = 0; i < students.length; i++) {
    const sid = ids[students[i].email];
    if (!sid) continue;
    let tasks = await get('ojt_daily_tasks?student_id=eq.' + sid + '&select=task_id');
    if (tasks.length === 0) continue;
    let links = tasks.map(t => ({ task_id: t.task_id, competency_id: compMap[i] }));
    for (let j = 0; j < links.length; j += 15) await post('task_competencies', links.slice(j, j + 15));
    console.log('  ' + students[i].full_name + ': ' + tasks.length + ' tasks → competency ' + compMap[i]);
  }

  // ─── STEP 7: Evaluations ───
  console.log('\n=== STEP 7: Evaluations ===');
  const evals = [
    { idx: 0, c: { attendance: 97, technical_skills: 94, communication: 91, initiative: 95, teamwork: 93 }, s: 94.0, f: 'Outstanding intern. Consistently arrives early and produces excellent code. Highly recommend for full-time hire.' },
    { idx: 1, c: { attendance: 96, technical_skills: 90, communication: 93, initiative: 91, teamwork: 94 }, s: 92.8, f: 'Creative designer with strong attention to detail. Delivers polished UI work ahead of schedule.' },
    { idx: 2, c: { attendance: 93, technical_skills: 87, communication: 85, initiative: 82, teamwork: 88 }, s: 87.0, f: 'Reliable intern with strong data analysis skills. Good potential for growth in communication.' },
    { idx: 3, c: { attendance: 70, technical_skills: 78, communication: 72, initiative: 68, teamwork: 75 }, s: 72.6, f: 'Shows promise but frequent tardiness affects team. Needs to improve punctuality and time management.' },
    { idx: 4, c: { attendance: 98, technical_skills: 93, communication: 90, initiative: 96, teamwork: 92 }, s: 93.8, f: 'Exceptional work ethic and technical ability. Takes initiative on challenging tasks without prompting.' },
    { idx: 5, c: { attendance: 95, technical_skills: 91, communication: 88, initiative: 89, teamwork: 92 }, s: 91.0, f: 'Strong networking skills. Successfully configured office network infrastructure with minimal supervision.' },
    { idx: 6, c: { attendance: 40, technical_skills: 60, communication: 55, initiative: 35, teamwork: 50 }, s: 48.0, f: 'CRITICAL: Multiple GPS spoofing incidents detected. Several attendance entries rejected. Integrity concerns raised — recommend coordinator review.' },
    { idx: 7, c: { attendance: 92, technical_skills: 85, communication: 84, initiative: 80, teamwork: 86 }, s: 85.4, f: 'Diligent worker in information security. Demonstrates good attention to detail in vulnerability assessments.' },
    { idx: 8, c: { attendance: 77, technical_skills: 83, communication: 88, initiative: 81, teamwork: 87 }, s: 83.2, f: 'Excellent customer service skills. 3 absences noted but overall performance is satisfactory. Should improve attendance.' },
    { idx: 9, c: { attendance: 68, technical_skills: 76, communication: 74, initiative: 65, teamwork: 73 }, s: 71.2, f: 'Capable of good work when focused. Habitual tardiness (Mon/Wed/Fri) noticeable. Needs structured schedule.' },
  ];

  for (const e of evals) {
    const sid = ids[students[e.idx].email];
    if (!sid) continue;
    await post('evaluations', {
      student_id: sid,
      supervisor_id: SUPER_ID,
      criteria: e.c,
      total_score: e.s,
      feedback: e.f,
      evaluation_period_start: '2026-03-20',
      evaluation_period_end: '2026-04-10',
      status: 'Submitted'
    });
  }
  console.log('  ✚ 10 evaluations inserted');

  // ─── STEP 8: AI Insights ───
  console.log('\n=== STEP 8: AI Insights ===');
  const insights = [
    { idx: 0, r: { predicted_performance: 'Excellent', risk_level: 'Low', predicted_grade: '1.25', completion_probability: 0.98, strengths: ['punctuality', 'technical_skills', 'initiative'], recommendation: 'Top performer. Strong candidate for employment offer.' }, c: 0.96 },
    { idx: 1, r: { predicted_performance: 'Excellent', risk_level: 'Low', predicted_grade: '1.25', completion_probability: 0.97, strengths: ['creativity', 'ui_design', 'communication'], recommendation: 'Excellent design skills. Should consider UX specialization.' }, c: 0.94 },
    { idx: 2, r: { predicted_performance: 'Good', risk_level: 'Low', predicted_grade: '1.75', completion_probability: 0.93, strengths: ['data_analysis', 'sql_skills', 'reliability'], recommendation: 'Solid performer. Encourage more proactive communication.' }, c: 0.88 },
    { idx: 3, r: { predicted_performance: 'Average', risk_level: 'Medium', predicted_grade: '2.50', completion_probability: 0.78, strengths: ['technical_knowledge'], recommendation: 'Attendance improvement plan required. Frequent late arrivals affecting output quality.' }, c: 0.80 },
    { idx: 4, r: { predicted_performance: 'Excellent', risk_level: 'Low', predicted_grade: '1.25', completion_probability: 0.98, strengths: ['initiative', 'problem_solving', 'punctuality'], recommendation: 'Outstanding work ethic. Consider for advanced project assignments.' }, c: 0.95 },
    { idx: 5, r: { predicted_performance: 'Excellent', risk_level: 'Low', predicted_grade: '1.50', completion_probability: 0.95, strengths: ['networking', 'infrastructure', 'teamwork'], recommendation: 'Strong IT infrastructure skills. Well-suited for system admin role.' }, c: 0.91 },
    { idx: 6, r: { predicted_performance: 'At Risk', risk_level: 'Critical', predicted_grade: '5.00', completion_probability: 0.25, strengths: [], recommendation: 'CRITICAL: Multiple GPS spoofing incidents. Recommend immediate coordinator intervention and possible disciplinary action.', flags: ['FAKE_GPS_DETECTED', 'INTEGRITY_VIOLATION', 'TRUST_SCORE_CRITICAL'] }, c: 0.92 },
    { idx: 7, r: { predicted_performance: 'Good', risk_level: 'Low', predicted_grade: '1.75', completion_probability: 0.91, strengths: ['security_analysis', 'documentation', 'attention_to_detail'], recommendation: 'Reliable performer in InfoSec. Could benefit from more hands-on pentesting experience.' }, c: 0.86 },
    { idx: 8, r: { predicted_performance: 'Good', risk_level: 'Low-Medium', predicted_grade: '2.00', completion_probability: 0.86, strengths: ['customer_service', 'communication', 'teamwork'], recommendation: 'Strong interpersonal skills. Needs to maintain better attendance to reach full potential.' }, c: 0.83 },
    { idx: 9, r: { predicted_performance: 'Average', risk_level: 'Medium', predicted_grade: '2.75', completion_probability: 0.75, strengths: ['data_management'], recommendation: 'Capable but inconsistent. Tardiness pattern (Mon/Wed/Fri) needs structured intervention.' }, c: 0.77 },
  ];

  for (const a of insights) {
    const sid = ids[students[a.idx].email];
    if (!sid) continue;
    await post('ai_insights', {
      student_id: sid,
      model_name: 'OJT-Predictor-v2',
      insight_type: 'performance_prediction',
      result: a.r,
      confidence: a.c,
      input_data: { source: 'mock_seed_v2' },
      model_version: 'v2.1'
    });
  }
  console.log('  ✚ 10 AI insights inserted');

  // ─── DONE ───
  console.log('\n╔══════════════════════════════════════════════════════╗');
  console.log('║  ✅ DONE! All mock data seeded successfully.         ║');
  console.log('║                                                      ║');
  console.log('║  Coordinator : momo – mark jarantilla (id:22)        ║');
  console.log('║  Supervisor  : loloy – loyloy (id:6)                 ║');
  console.log('║  Students    : 10 BSCS students                      ║');
  console.log('║  Period      : 2026-03-20 → 2026-04-10               ║');
  console.log('║  Fake GPS    : Jessa Marie Castillo (idx 6)          ║');
  console.log('║                                                      ║');
  console.log('║  Records created:                                    ║');
  console.log('║    • 10 students                                     ║');
  console.log('║    • 1 OJT site                                      ║');
  console.log('║    • 10 OJT records                                  ║');
  console.log('║    • ~147 attendance records                          ║');
  console.log('║    • ~147 daily tasks                                 ║');
  console.log('║    • 10 evaluations                                   ║');
  console.log('║    • 10 AI insights                                   ║');
  console.log('╚══════════════════════════════════════════════════════╝');
}

main().catch(e => console.error('FATAL:', e));
