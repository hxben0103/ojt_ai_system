// Minimal seed script using fetch (Node 18+ built-in)
const BASE = 'https://vykprjzttyjpnptzbinl.supabase.co/rest/v1';
const KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ5a3Byanp0dHlqcG5wdHpiaW5sIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MjAzMTE4MSwiZXhwIjoyMDg3NjA3MTgxfQ.9htyC9wNZTkxWPLhjdlqZ-rmmefztsq5Av63wj4ysvM';
const H = { 'apikey': KEY, 'Authorization': 'Bearer ' + KEY, 'Content-Type': 'application/json', 'Prefer': 'return=representation' };

async function post(ep, data) {
  const r = await fetch(BASE + '/' + ep, { method: 'POST', headers: H, body: JSON.stringify(data) });
  const t = await r.text();
  if (!r.ok && r.status !== 409) console.error('ERR ' + ep + ': ' + r.status + ' ' + t.substring(0, 200));
  return r.ok ? JSON.parse(t) : null;
}
async function get(ep) {
  const r = await fetch(BASE + '/' + ep, { headers: { 'apikey': KEY, 'Authorization': 'Bearer ' + KEY } });
  return r.ok ? r.json() : [];
}

const COORD = 22, SUPER = 6;
const CL = 10.3157, CN = 123.8854;
const rand = (a, b) => a + Math.random() * (b - a);
const ri = (a, b) => Math.floor(rand(a, b + 1));

async function main() {
  console.log('=== STEP 1: Create 5 BSCS Students ===');
  const stus = [
    { full_name:'Juan Carlo Dela Cruz', email:'juancarlo.delacruz@student.cit.edu', student_id:'2022-0001', age:21, gender:'Male', contact_number:'09191111111', address:'Mandaue City' },
    { full_name:'Maria Angela Santos', email:'maria.santos@student.cit.edu', student_id:'2022-0002', age:20, gender:'Female', contact_number:'09192222222', address:'Lapu-Lapu City' },
    { full_name:'Rafael James Reyes', email:'rafael.reyes@student.cit.edu', student_id:'2022-0003', age:22, gender:'Male', contact_number:'09193333333', address:'Talisay City' },
    { full_name:'Patricia Mae Gonzales', email:'patricia.gonzales@student.cit.edu', student_id:'2022-0004', age:21, gender:'Female', contact_number:'09194444444', address:'Toledo City' },
    { full_name:'Miguel Antonio Ramos', email:'miguel.ramos@student.cit.edu', student_id:'2022-0005', age:23, gender:'Male', contact_number:'09195555555', address:'Consolacion' },
  ];
  const ids = {};
  for (const s of stus) {
    let ex = await get('users?email=eq.' + encodeURIComponent(s.email) + '&select=user_id');
    if (ex.length > 0) { ids[s.email] = ex[0].user_id; console.log('  exists: ' + s.full_name + ' id=' + ex[0].user_id); continue; }
    let r = await post('users', { ...s, password_hash:'$2b$10$QJXZ9K1LhV8v8o6Y7nD3zO5p8q2w4E6y8I0u2W4q6E8y0I2u4W6q', role:'Student', status:'Active', course:'BSCS', required_hours:300 });
    if (r && r[0]) { ids[s.email] = r[0].user_id; console.log('  created: ' + s.full_name + ' id=' + r[0].user_id); }
  }

  console.log('\n=== STEP 2: OJT Site ===');
  let sites = await get('ojt_sites?name=eq.' + encodeURIComponent('TechPartner Solutions Office') + '&select=id');
  if (sites.length === 0) { await post('ojt_sites', { name:'TechPartner Solutions Office', latitude:CL, longitude:CN, radius_meters:100, company_name:'TechPartner Solutions Inc.' }); console.log('  created'); }
  else console.log('  exists');

  console.log('\n=== STEP 3: OJT Records → coordinator momo (22) ===');
  for (const s of stus) {
    const sid = ids[s.email]; if (!sid) continue;
    let ex = await get('ojt_records?student_id=eq.' + sid + '&select=record_id');
    if (ex.length > 0) { console.log('  exists: ' + s.full_name); continue; }
    await post('ojt_records', { student_id:sid, company_name:'TechPartner Solutions Inc.', coordinator_id:COORD, supervisor_id:SUPER, start_date:'2026-03-20', end_date:'2026-06-20', status:'Ongoing', required_hours:300, company_address:'Cebu IT Park, Cebu City', company_contact:'032-1234567' });
    console.log('  created: ' + s.full_name);
  }

  console.log('\n=== STEP 4: Attendance (Mar 20 - Apr 10) ===');
  const profiles = ['excellent','great','average','fake_gps','good_absent'];
  const absent = ['2026-03-25','2026-04-01','2026-04-07'];
  let attBatch = [];
  let d = new Date('2026-03-20');
  while (d <= new Date('2026-04-10')) {
    const dow = d.getDay();
    if (dow !== 0 && dow !== 6) {
      const ds = d.toISOString().split('T')[0];
      for (let i = 0; i < 5; i++) {
        const sid = ids[stus[i].email]; if (!sid) continue;
        const p = profiles[i];
        if (p === 'good_absent' && absent.includes(ds)) continue;
        let mi,mo='12:00:00',ai='13:00:00',ao='17:00:00',st,vf,vb,lat,lng,acc,dist,ig,ts,tf,vs;
        if (p==='excellent') { mi='07:55:00'; st='Approved'; vf=true; vb=SUPER; lat=CL+rand(-.0001,.0001); lng=CN+rand(-.0001,.0001); acc=rand(5,15); dist=rand(5,25); ig=true; ts=ri(95,100); tf='TRUSTED'; vs='AUTO_VERIFIED'; }
        else if (p==='great') { mi='07:50:00'; st='Approved'; vf=true; vb=SUPER; lat=CL+rand(-.00015,.00015); lng=CN+rand(-.00015,.00015); acc=rand(6,18); dist=rand(8,38); ig=true; ts=ri(92,100); tf='TRUSTED'; vs='AUTO_VERIFIED'; }
        else if (p==='average') { mi=dow===1||dow===3?'08:00:00':dow===2?'08:15:00':dow===4?'08:35:00':'08:10:00'; st='Approved'; vf=true; vb=SUPER; lat=CL+rand(-.00015,.00015); lng=CN+rand(-.00015,.00015); acc=rand(8,23); dist=rand(10,50); ig=true; ts=ri(80,94); tf='TRUSTED'; vs='AUTO_VERIFIED'; }
        else if (p==='fake_gps') {
          mi='08:00:00';
          if (dow===1||dow===4) { st='Rejected'; vf=false; vb=null; } else { st='Approved'; vf=true; vb=SUPER; }
          if (dow===2||dow===5) { lat=CL+0.015; lng=CN-0.012; dist=rand(1600,2000); }
          else if (dow===3) { lat=CL-0.008; lng=CN+0.010; dist=rand(800,1000); }
          else { lat=CL+0.005; lng=CN-0.004; dist=rand(400,600); }
          acc=rand(500,2000); ig=false; ts=ri(10,34); tf='MOCK_LOCATION,HIGH_ACCURACY_ERROR,LOCATION_JUMP'; vs='FLAGGED_FAKE_GPS';
        }
        else { mi='07:58:00'; st='Approved'; vf=true; vb=SUPER; lat=CL+rand(-.0001,.0001); lng=CN+rand(-.0001,.0001); acc=rand(4,12); dist=rand(5,30); ig=true; ts=ri(90,100); tf='TRUSTED'; vs='AUTO_VERIFIED'; }
        attBatch.push({ student_id:sid, date:ds, morning_in:mi, morning_out:mo, afternoon_in:ai, afternoon_out:ao, status:st, verified:vf, verified_by:vb, checkin_lat:Math.round(lat*1e5)/1e5, checkin_lng:Math.round(lng*1e5)/1e5, accuracy_m:Math.round(acc*10)/10, distance_m:Math.round(dist*10)/10, inside_geofence:ig, trust_score:ts, trust_flags:tf, verification_status:vs });
      }
    }
    d.setDate(d.getDate()+1);
  }
  let ac = 0;
  for (let i=0; i<attBatch.length; i+=15) { let r = await post('attendance', attBatch.slice(i,i+15)); if(r) ac+=r.length; }
  console.log('  inserted: ' + ac + ' attendance records');

  console.log('\n=== STEP 5: Daily Tasks ===');
  const taskDescs = [
    ['Set up dev environment and cloned project repo','Implemented JWT auth module','Built REST API for attendance tracking','Code review and bug fixes'],
    ['Created wireframes for dashboard','Designed mockups for student profiles','Implemented responsive CSS for mobile','Usability testing and documentation'],
    ['Cleaned and preprocessed datasets','Generated attendance trend reports in SQL','Created data visualizations for dashboard','Optimized DB queries for reporting'],
    ['Hardware inventory and asset tagging','IT support tickets and resolutions','Software updates on workstations','Troubleshot network issues'],
    ['Configured switches and network topology','Set up VLANs and routing','Monitored traffic with Wireshark','Deployed firewall rules'],
  ];
  let taskBatch = [];
  d = new Date('2026-03-20');
  while (d <= new Date('2026-04-10')) {
    const dow = d.getDay();
    if (dow !== 0 && dow !== 6) {
      const ds = d.toISOString().split('T')[0];
      const wk = Math.min(3, Math.floor((d - new Date('2026-03-20'))/(7*864e5)));
      for (let i=0; i<5; i++) {
        const sid = ids[stus[i].email]; if (!sid) continue;
        const p = profiles[i];
        if (p==='good_absent' && absent.includes(ds)) continue;
        let ts, rm, hw=8;
        if (p==='fake_gps'&&(dow===1||dow===4)) { ts='Rejected'; rm='GPS location flagged'; }
        else if (p==='average'&&(dow===2||dow===4)) { ts=dow===4?'Pending':'Approved'; rm='Noted: arrived late'; hw=7; }
        else { ts='Approved'; rm=p==='excellent'?'Excellent work':p==='great'?'Creative and thorough':p==='good_absent'?'Solid performance':'Completed on-site'; }
        taskBatch.push({ student_id:sid, date:ds, task_description:taskDescs[i][wk], hours_worked:hw, supervisor_id:SUPER, status:ts, remarks:rm });
      }
    }
    d.setDate(d.getDate()+1);
  }
  let tc = 0;
  for (let i=0; i<taskBatch.length; i+=15) { let r = await post('ojt_daily_tasks', taskBatch.slice(i,i+15)); if(r) tc+=r.length; }
  console.log('  inserted: ' + tc + ' tasks');

  console.log('\n=== STEP 6: Task-Competency Links ===');
  const compIds = [1,4,8,7,6]; // SD, UI, DA, TS, NET
  for (let i=0; i<5; i++) {
    const sid = ids[stus[i].email]; if (!sid) continue;
    let tasks = await get('ojt_daily_tasks?student_id=eq.'+sid+'&select=task_id');
    if (tasks.length === 0) continue;
    let links = tasks.map(t => ({ task_id:t.task_id, competency_id:compIds[i] }));
    for (let j=0; j<links.length; j+=15) await post('task_competencies', links.slice(j,j+15));
    console.log('  ' + stus[i].full_name + ': ' + tasks.length + ' linked');
  }

  console.log('\n=== STEP 7: Evaluations ===');
  const evals = [
    { idx:0, c:{attendance:95,technical_skills:92,communication:90,initiative:93,teamwork:91}, s:92.2, f:'Outstanding intern. Very proactive with strong coding skills.' },
    { idx:1, c:{attendance:96,technical_skills:88,communication:94,initiative:90,teamwork:93}, s:92.2, f:'Excellent design sense. UI work improved product mockups significantly.' },
    { idx:2, c:{attendance:72,technical_skills:80,communication:75,initiative:70,teamwork:78}, s:75.0, f:'Good potential but needs to improve punctuality. Tardiness affects output.' },
    { idx:3, c:{attendance:45,technical_skills:65,communication:60,initiative:40,teamwork:55}, s:53.0, f:'Multiple GPS anomalies flagged. Several entries rejected for suspected spoofing.' },
    { idx:4, c:{attendance:78,technical_skills:87,communication:82,initiative:84,teamwork:86}, s:83.4, f:'Strong networking skills when present. 3 absences noted this period.' },
  ];
  for (const e of evals) {
    const sid = ids[stus[e.idx].email]; if (!sid) continue;
    await post('evaluations', { student_id:sid, supervisor_id:SUPER, criteria:e.c, total_score:e.s, feedback:e.f, evaluation_period_start:'2026-03-20', evaluation_period_end:'2026-04-10', status:'Submitted' });
  }
  console.log('  5 evaluations inserted');

  console.log('\n=== STEP 8: AI Insights ===');
  const ais = [
    { idx:0, r:{predicted_performance:'Excellent',risk_level:'Low',predicted_grade:'1.25',completion_probability:0.98,strengths:['punctuality','technical_skills','initiative'],recommendation:'Strong candidate for employment offer.'}, c:0.94 },
    { idx:1, r:{predicted_performance:'Excellent',risk_level:'Low',predicted_grade:'1.25',completion_probability:0.97,strengths:['creativity','communication','design_skills'],recommendation:'Should consider UX specialization.'}, c:0.92 },
    { idx:2, r:{predicted_performance:'Average',risk_level:'Medium',predicted_grade:'2.50',completion_probability:0.82,strengths:['data_analysis','sql_skills'],recommendation:'Needs attendance improvement plan.'}, c:0.78 },
    { idx:3, r:{predicted_performance:'At Risk',risk_level:'Critical',predicted_grade:'4.00',completion_probability:0.35,strengths:[],recommendation:'CRITICAL: Multiple GPS spoofing incidents. Recommend coordinator intervention.',flags:['FAKE_GPS_DETECTED','INTEGRITY_VIOLATION']}, c:0.89 },
    { idx:4, r:{predicted_performance:'Good',risk_level:'Low-Medium',predicted_grade:'1.75',completion_probability:0.88,strengths:['networking_skills','teamwork'],recommendation:'Strong performer. Should maintain better attendance.'}, c:0.85 },
  ];
  for (const a of ais) {
    const sid = ids[stus[a.idx].email]; if (!sid) continue;
    await post('ai_insights', { student_id:sid, model_name:'OJT-Predictor-v2', insight_type:'performance_prediction', result:a.r, confidence:a.c, input_data:{source:'mock_seed'}, model_version:'v2.1' });
  }
  console.log('  5 AI insights inserted');

  console.log('\n============================');
  console.log('DONE! All mock data seeded.');
  console.log('Coordinator: momo (id:22)');
  console.log('All students: BSCS');
  console.log('Fake GPS: Patricia Mae Gonzales');
  console.log('============================');
}
main().catch(e => console.error(e));
