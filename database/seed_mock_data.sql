-- =====================================================
-- SEED MOCK DATA: 5 Students, March 20 – April 10, 2026
-- =====================================================
-- ⚠️  RUN AFTER: schema_full.sql, all migrations, seed_competencies.sql
-- ⚠️  This script is IDEMPOTENT: uses ON CONFLICT / WHERE NOT EXISTS guards
-- =====================================================

-- =====================================================
-- STEP 0: CONFIGURATION
-- =====================================================
-- OJT Site: CIT-U Partner Company  (Cebu City)
-- Geofence center: 10.3157, 123.8854  (radius: 100m)
-- Schedule: Mon-Fri, 8:00 AM – 5:00 PM
-- =====================================================

-- =====================================================
-- STEP 1: INSERT USERS
-- =====================================================

-- 1A. Coordinator
INSERT INTO users (full_name, email, password_hash, role, status, student_id, course, age, gender, contact_number, address)
VALUES (
  'Ma. Teresa Villanueva', 'coordinator.villanueva@cit.edu', 
  '$2b$10$mockhashedpasswordcoordinator000000000000000000', 
  'Coordinator', 'Active', NULL, NULL, 45, 'Female', '09171234567', 'Cebu City'
)
ON CONFLICT (email) DO NOTHING;

-- 1B. Supervisor (company side)
INSERT INTO users (full_name, email, password_hash, role, status, student_id, course, age, gender, contact_number, address)
VALUES (
  'Engr. Roberto Cruz', 'supervisor.cruz@techpartner.com',
  '$2b$10$mockhashedpasswordsupervisor00000000000000000000',
  'Supervisor', 'Active', NULL, NULL, 38, 'Male', '09181234567', 'Cebu IT Park'
)
ON CONFLICT (email) DO NOTHING;

-- 1C. 5 Students (Real Filipino Names)
INSERT INTO users (full_name, email, password_hash, role, status, student_id, course, age, gender, contact_number, address, required_hours)
VALUES
  -- Student 1: Good performer
  ('Juan Carlo Dela Cruz', 'juancarlo.delacruz@student.cit.edu',
   '$2b$10$mockhashedpasswordstudent100000000000000000000',
   'Student', 'Active', '2022-0001', 'BSIT', 21, 'Male', '09191111111', 'Mandaue City', 300),
  -- Student 2: Good performer
  ('Maria Angela Santos', 'maria.santos@student.cit.edu',
   '$2b$10$mockhashedpasswordstudent200000000000000000000',
   'Student', 'Active', '2022-0002', 'BSIT', 20, 'Female', '09192222222', 'Lapu-Lapu City', 300),
  -- Student 3: Average performer, occasionally late
  ('Rafael James Reyes', 'rafael.reyes@student.cit.edu',
   '$2b$10$mockhashedpasswordstudent300000000000000000000',
   'Student', 'Active', '2022-0003', 'BSCS', 22, 'Male', '09193333333', 'Talisay City', 300),
  -- Student 4: ⚠️ FAKE GPS USER — flagged with low trust scores
  ('Patricia Mae Gonzales', 'patricia.gonzales@student.cit.edu',
   '$2b$10$mockhashedpasswordstudent400000000000000000000',
   'Student', 'Active', '2022-0004', 'BSIT', 21, 'Female', '09194444444', 'Toledo City', 300),
  -- Student 5: Good but absent sometimes
  ('Miguel Antonio Ramos', 'miguel.ramos@student.cit.edu',
   '$2b$10$mockhashedpasswordstudent500000000000000000000',
   'Student', 'Active', '2022-0005', 'BSCS', 23, 'Male', '09195555555', 'Consolacion', 300)
ON CONFLICT (email) DO NOTHING;

-- =====================================================
-- STEP 2: OJT SITE (Geofence)
-- =====================================================
INSERT INTO ojt_sites (name, latitude, longitude, radius_meters, company_name)
SELECT 'TechPartner Solutions Office', 10.3157, 123.8854, 100, 'TechPartner Solutions Inc.'
WHERE NOT EXISTS (SELECT 1 FROM ojt_sites WHERE name = 'TechPartner Solutions Office');

-- =====================================================
-- STEP 3: OJT RECORDS
-- =====================================================
-- Assign all 5 students to the coordinator & supervisor
DO $$
DECLARE
  v_coord_id INT;
  v_super_id INT;
  v_s1 INT; v_s2 INT; v_s3 INT; v_s4 INT; v_s5 INT;
BEGIN
  SELECT user_id INTO v_coord_id FROM users WHERE email = 'coordinator.villanueva@cit.edu';
  SELECT user_id INTO v_super_id FROM users WHERE email = 'supervisor.cruz@techpartner.com';
  SELECT user_id INTO v_s1 FROM users WHERE email = 'juancarlo.delacruz@student.cit.edu';
  SELECT user_id INTO v_s2 FROM users WHERE email = 'maria.santos@student.cit.edu';
  SELECT user_id INTO v_s3 FROM users WHERE email = 'rafael.reyes@student.cit.edu';
  SELECT user_id INTO v_s4 FROM users WHERE email = 'patricia.gonzales@student.cit.edu';
  SELECT user_id INTO v_s5 FROM users WHERE email = 'miguel.ramos@student.cit.edu';

  -- Create OJT records if not existing
  IF NOT EXISTS (SELECT 1 FROM ojt_records WHERE student_id = v_s1) THEN
    INSERT INTO ojt_records (student_id, company_name, coordinator_id, supervisor_id, start_date, end_date, status, required_hours, company_address, company_contact)
    VALUES (v_s1, 'TechPartner Solutions Inc.', v_coord_id, v_super_id, '2026-03-20', '2026-06-20', 'Ongoing', 300, 'Cebu IT Park, Cebu City', '032-1234567');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM ojt_records WHERE student_id = v_s2) THEN
    INSERT INTO ojt_records (student_id, company_name, coordinator_id, supervisor_id, start_date, end_date, status, required_hours, company_address, company_contact)
    VALUES (v_s2, 'TechPartner Solutions Inc.', v_coord_id, v_super_id, '2026-03-20', '2026-06-20', 'Ongoing', 300, 'Cebu IT Park, Cebu City', '032-1234567');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM ojt_records WHERE student_id = v_s3) THEN
    INSERT INTO ojt_records (student_id, company_name, coordinator_id, supervisor_id, start_date, end_date, status, required_hours, company_address, company_contact)
    VALUES (v_s3, 'TechPartner Solutions Inc.', v_coord_id, v_super_id, '2026-03-20', '2026-06-20', 'Ongoing', 300, 'Cebu IT Park, Cebu City', '032-1234567');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM ojt_records WHERE student_id = v_s4) THEN
    INSERT INTO ojt_records (student_id, company_name, coordinator_id, supervisor_id, start_date, end_date, status, required_hours, company_address, company_contact)
    VALUES (v_s4, 'TechPartner Solutions Inc.', v_coord_id, v_super_id, '2026-03-20', '2026-06-20', 'Ongoing', 300, 'Cebu IT Park, Cebu City', '032-1234567');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM ojt_records WHERE student_id = v_s5) THEN
    INSERT INTO ojt_records (student_id, company_name, coordinator_id, supervisor_id, start_date, end_date, status, required_hours, company_address, company_contact)
    VALUES (v_s5, 'TechPartner Solutions Inc.', v_coord_id, v_super_id, '2026-03-20', '2026-06-20', 'Ongoing', 300, 'Cebu IT Park, Cebu City', '032-1234567');
  END IF;
END $$;

-- =====================================================
-- STEP 4: ATTENDANCE DATA (March 20 – April 10, 2026)
-- =====================================================
-- Weekdays only. Skipping weekends automatically.
-- Geofence center: lat=10.3157, lng=123.8854
--
-- STUDENT PROFILES:
-- S1 (Juan Carlo)   – Excellent: always on time, inside geofence, high trust
-- S2 (Maria Angela) – Great: on time, inside geofence, high trust
-- S3 (Rafael James) – Average: sometimes late (10-45 min), inside geofence
-- S4 (Patricia Mae) – ⚠️ FAKE GPS: outside geofence, low trust, suspicious accuracy
-- S5 (Miguel)       – Good but absent 3 days

DO $$
DECLARE
  v_super_id INT;
  v_s1 INT; v_s2 INT; v_s3 INT; v_s4 INT; v_s5 INT;
  v_date DATE;
  v_dow INT;
  -- Geofence center
  v_center_lat DOUBLE PRECISION := 10.3157;
  v_center_lng DOUBLE PRECISION := 123.8854;
BEGIN
  SELECT user_id INTO v_super_id FROM users WHERE email = 'supervisor.cruz@techpartner.com';
  SELECT user_id INTO v_s1 FROM users WHERE email = 'juancarlo.delacruz@student.cit.edu';
  SELECT user_id INTO v_s2 FROM users WHERE email = 'maria.santos@student.cit.edu';
  SELECT user_id INTO v_s3 FROM users WHERE email = 'rafael.reyes@student.cit.edu';
  SELECT user_id INTO v_s4 FROM users WHERE email = 'patricia.gonzales@student.cit.edu';
  SELECT user_id INTO v_s5 FROM users WHERE email = 'miguel.ramos@student.cit.edu';

  v_date := '2026-03-20';

  WHILE v_date <= '2026-04-10' LOOP
    v_dow := EXTRACT(DOW FROM v_date);

    -- Skip weekends
    IF v_dow NOT IN (0, 6) THEN

      -- ============================
      -- STUDENT 1: Juan Carlo — Perfect attendance, always on time
      -- ============================
      IF NOT EXISTS (SELECT 1 FROM attendance WHERE student_id = v_s1 AND date = v_date) THEN
        INSERT INTO attendance (
          student_id, date, morning_in, morning_out, afternoon_in, afternoon_out,
          status, verified, verified_by,
          checkin_lat, checkin_lng, accuracy_m, distance_m, inside_geofence, trust_score, trust_flags,
          verification_status
        ) VALUES (
          v_s1, v_date, '07:55:00', '12:00:00', '13:00:00', '17:00:00',
          'Approved', TRUE, v_super_id,
          v_center_lat + (random() * 0.0002 - 0.0001), v_center_lng + (random() * 0.0002 - 0.0001),
          5.0 + random() * 10,  -- accuracy: 5-15m (excellent)
          5.0 + random() * 20,  -- distance: 5-25m from center (inside 100m fence)
          TRUE, 95 + FLOOR(random() * 6)::INT, -- trust: 95-100
          'TRUSTED',
          'AUTO_VERIFIED'
        );
      END IF;

      -- ============================
      -- STUDENT 2: Maria Angela — Great attendance, always on time
      -- ============================
      IF NOT EXISTS (SELECT 1 FROM attendance WHERE student_id = v_s2 AND date = v_date) THEN
        INSERT INTO attendance (
          student_id, date, morning_in, morning_out, afternoon_in, afternoon_out,
          status, verified, verified_by,
          checkin_lat, checkin_lng, accuracy_m, distance_m, inside_geofence, trust_score, trust_flags,
          verification_status
        ) VALUES (
          v_s2, v_date, '07:50:00', '12:00:00', '13:00:00', '17:00:00',
          'Approved', TRUE, v_super_id,
          v_center_lat + (random() * 0.0003 - 0.00015), v_center_lng + (random() * 0.0003 - 0.00015),
          6.0 + random() * 12,  -- accuracy: 6-18m
          8.0 + random() * 30,  -- distance: 8-38m
          TRUE, 92 + FLOOR(random() * 9)::INT, -- trust: 92-100
          'TRUSTED',
          'AUTO_VERIFIED'
        );
      END IF;

      -- ============================
      -- STUDENT 3: Rafael James — Sometimes late (varies by day)
      -- ============================
      IF NOT EXISTS (SELECT 1 FROM attendance WHERE student_id = v_s3 AND date = v_date) THEN
        INSERT INTO attendance (
          student_id, date,
          morning_in, morning_out, afternoon_in, afternoon_out,
          status, verified, verified_by,
          checkin_lat, checkin_lng, accuracy_m, distance_m, inside_geofence, trust_score, trust_flags,
          verification_status
        ) VALUES (
          v_s3, v_date,
          -- Late pattern: Mon/Wed on time, Tue/Thu late 15-45 min, Fri sometimes late
          CASE
            WHEN v_dow IN (1, 3) THEN '08:00:00'::TIME          -- Mon, Wed: on time
            WHEN v_dow = 2 THEN '08:15:00'::TIME                 -- Tue: 15 min late
            WHEN v_dow = 4 THEN '08:35:00'::TIME                 -- Thu: 35 min late
            WHEN v_dow = 5 THEN '08:10:00'::TIME                 -- Fri: 10 min late
          END,
          '12:00:00', '13:00:00', '17:00:00',
          'Approved', TRUE, v_super_id,
          v_center_lat + (random() * 0.0003 - 0.00015), v_center_lng + (random() * 0.0003 - 0.00015),
          8.0 + random() * 15,  -- accuracy: 8-23m
          10.0 + random() * 40, -- distance: 10-50m
          TRUE, 80 + FLOOR(random() * 15)::INT, -- trust: 80-94 (lower due to tardiness flagging)
          'TRUSTED',
          'AUTO_VERIFIED'
        );
      END IF;

      -- ============================
      -- STUDENT 4: Patricia Mae — ⚠️ FAKE GPS USER
      -- ============================
      -- Telltale signs:
      --   • inside_geofence = FALSE on many days
      --   • accuracy_m very high (500-2000m) = mock location provider
      --   • distance_m > 100m (outside fence)
      --   • trust_score < 50
      --   • trust_flags = 'MOCK_LOCATION,HIGH_ACCURACY_ERROR,LOCATION_JUMP'
      --   • Some days she "appears" inside to try to fool the system
      IF NOT EXISTS (SELECT 1 FROM attendance WHERE student_id = v_s4 AND date = v_date) THEN
        INSERT INTO attendance (
          student_id, date, morning_in, morning_out, afternoon_in, afternoon_out,
          status, verified, verified_by,
          checkin_lat, checkin_lng, accuracy_m, distance_m, inside_geofence, trust_score, trust_flags,
          verification_status
        ) VALUES (
          v_s4, v_date,
          -- She logs in "on time" but from fake location
          '08:00:00', '12:00:00', '13:00:00', '17:00:00',
          -- Status depends on trust — coordinator flags some as Rejected
          CASE
            WHEN v_dow IN (1, 4) THEN 'Rejected'   -- Mon & Thu: coordinator caught it
            ELSE 'Approved'                         -- Other days: slipped through
          END,
          CASE WHEN v_dow IN (1, 4) THEN FALSE ELSE TRUE END,
          CASE WHEN v_dow IN (1, 4) THEN NULL ELSE v_super_id END,
          -- Fake GPS coords: far from actual site
          CASE
            WHEN v_dow IN (2, 5) THEN v_center_lat + 0.015  -- ~1.6km north (Manila-like coords)
            WHEN v_dow = 3 THEN v_center_lat - 0.008          -- ~900m south
            ELSE v_center_lat + 0.005                          -- ~550m off
          END,
          CASE
            WHEN v_dow IN (2, 5) THEN v_center_lng - 0.012
            WHEN v_dow = 3 THEN v_center_lng + 0.010
            ELSE v_center_lng - 0.004
          END,
          -- Fake GPS apps produce very high accuracy error values
          500.0 + random() * 1500,  -- accuracy: 500-2000m (very suspicious!)
          -- Distance from geofence center
          CASE
            WHEN v_dow IN (2, 5) THEN 1600 + random() * 400  -- 1.6-2.0 km away
            WHEN v_dow = 3 THEN 800 + random() * 200          -- 800m-1km away
            ELSE 400 + random() * 200                          -- 400-600m away
          END,
          FALSE,  -- outside geofence
          -- Trust score: very low
          10 + FLOOR(random() * 25)::INT,  -- trust: 10-34 (VERY LOW)
          'MOCK_LOCATION,HIGH_ACCURACY_ERROR,LOCATION_JUMP',
          'FLAGGED_FAKE_GPS'
        );
      END IF;

      -- ============================
      -- STUDENT 5: Miguel Antonio — Good but absent 3 days
      -- ============================
      -- Absent on: March 25 (Wed), April 1 (Wed), April 7 (Tue)
      IF v_date NOT IN ('2026-03-25', '2026-04-01', '2026-04-07') THEN
        IF NOT EXISTS (SELECT 1 FROM attendance WHERE student_id = v_s5 AND date = v_date) THEN
          INSERT INTO attendance (
            student_id, date, morning_in, morning_out, afternoon_in, afternoon_out,
            status, verified, verified_by,
            checkin_lat, checkin_lng, accuracy_m, distance_m, inside_geofence, trust_score, trust_flags,
            verification_status
          ) VALUES (
            v_s5, v_date, '07:58:00', '12:00:00', '13:00:00', '17:00:00',
            'Approved', TRUE, v_super_id,
            v_center_lat + (random() * 0.0002 - 0.0001), v_center_lng + (random() * 0.0002 - 0.0001),
            4.0 + random() * 8,  -- accuracy: 4-12m (great)
            5.0 + random() * 25, -- distance: 5-30m
            TRUE, 90 + FLOOR(random() * 11)::INT, -- trust: 90-100
            'TRUSTED',
            'AUTO_VERIFIED'
          );
        END IF;
      END IF;

    END IF; -- end weekday check

    v_date := v_date + 1;
  END LOOP;
END $$;


-- =====================================================
-- STEP 5: DAILY TASKS (one task per student per attendance day)
-- =====================================================
DO $$
DECLARE
  v_super_id INT;
  v_s1 INT; v_s2 INT; v_s3 INT; v_s4 INT; v_s5 INT;
  v_date DATE;
  v_dow INT;
  v_week INT := 0;
  v_task_desc TEXT;
  v_comp_title TEXT;
BEGIN
  SELECT user_id INTO v_super_id FROM users WHERE email = 'supervisor.cruz@techpartner.com';
  SELECT user_id INTO v_s1 FROM users WHERE email = 'juancarlo.delacruz@student.cit.edu';
  SELECT user_id INTO v_s2 FROM users WHERE email = 'maria.santos@student.cit.edu';
  SELECT user_id INTO v_s3 FROM users WHERE email = 'rafael.reyes@student.cit.edu';
  SELECT user_id INTO v_s4 FROM users WHERE email = 'patricia.gonzales@student.cit.edu';
  SELECT user_id INTO v_s5 FROM users WHERE email = 'miguel.ramos@student.cit.edu';

  v_date := '2026-03-20';

  WHILE v_date <= '2026-04-10' LOOP
    v_dow := EXTRACT(DOW FROM v_date);

    IF v_dow NOT IN (0, 6) THEN
      -- Track week number for task variety
      v_week := (v_date - '2026-03-20'::DATE) / 7;

      -- ---- S1: Juan Carlo — Software Development tasks ----
      v_task_desc := CASE v_week
        WHEN 0 THEN 'Set up development environment and cloned project repository'
        WHEN 1 THEN 'Implemented user authentication module with JWT tokens'
        WHEN 2 THEN 'Built REST API endpoints for student attendance tracking'
        ELSE 'Performed code review and fixed reported bugs'
      END;

      IF NOT EXISTS (SELECT 1 FROM ojt_daily_tasks WHERE student_id = v_s1 AND date = v_date) THEN
        INSERT INTO ojt_daily_tasks (student_id, date, task_description, hours_worked, supervisor_id, status, remarks)
        VALUES (v_s1, v_date, v_task_desc, 8.0, v_super_id, 'Approved', 'Excellent work');
      END IF;

      -- ---- S2: Maria Angela — UI Design tasks ----
      v_task_desc := CASE v_week
        WHEN 0 THEN 'Created wireframes for the dashboard module'
        WHEN 1 THEN 'Designed high-fidelity mockups for student profiles'
        WHEN 2 THEN 'Implemented responsive CSS layouts for mobile views'
        ELSE 'Conducted usability testing and documented findings'
      END;

      IF NOT EXISTS (SELECT 1 FROM ojt_daily_tasks WHERE student_id = v_s2 AND date = v_date) THEN
        INSERT INTO ojt_daily_tasks (student_id, date, task_description, hours_worked, supervisor_id, status, remarks)
        VALUES (v_s2, v_date, v_task_desc, 8.0, v_super_id, 'Approved', 'Creative and thorough');
      END IF;

      -- ---- S3: Rafael James — Data Analysis tasks ----
      v_task_desc := CASE v_week
        WHEN 0 THEN 'Cleaned and preprocessed raw attendance datasets'
        WHEN 1 THEN 'Generated attendance trend reports using SQL queries'
        WHEN 2 THEN 'Created data visualizations for coordinator dashboard'
        ELSE 'Optimized database queries for performance reporting'
      END;

      IF NOT EXISTS (SELECT 1 FROM ojt_daily_tasks WHERE student_id = v_s3 AND date = v_date) THEN
        INSERT INTO ojt_daily_tasks (student_id, date, task_description, hours_worked, supervisor_id, status,
          remarks)
        VALUES (v_s3, v_date, v_task_desc,
          CASE WHEN v_dow IN (2, 4) THEN 7.0 ELSE 8.0 END,  -- less hours on late days
          v_super_id,
          CASE WHEN v_dow = 4 THEN 'Pending' ELSE 'Approved' END,  -- Thu tasks sometimes pending
          CASE WHEN v_dow IN (2, 4) THEN 'Noted: arrived late' ELSE 'Satisfactory' END
        );
      END IF;

      -- ---- S4: Patricia Mae — Technical Support tasks ----
      v_task_desc := CASE v_week
        WHEN 0 THEN 'Assisted with hardware inventory and asset tagging'
        WHEN 1 THEN 'Responded to IT support tickets and documented resolutions'
        WHEN 2 THEN 'Installed software updates on office workstations'
        ELSE 'Troubleshot network connectivity issues'
      END;

      IF NOT EXISTS (SELECT 1 FROM ojt_daily_tasks WHERE student_id = v_s4 AND date = v_date) THEN
        INSERT INTO ojt_daily_tasks (student_id, date, task_description, hours_worked, supervisor_id, status,
          remarks)
        VALUES (v_s4, v_date, v_task_desc, 8.0, v_super_id,
          CASE WHEN v_dow IN (1, 4) THEN 'Rejected' ELSE 'Approved' END,  -- matches attendance rejections
          CASE WHEN v_dow IN (1, 4) THEN 'GPS location flagged — task unverifiable' ELSE 'Completed on-site' END
        );
      END IF;

      -- ---- S5: Miguel Antonio — Networking tasks ----
      IF v_date NOT IN ('2026-03-25', '2026-04-01', '2026-04-07') THEN
        v_task_desc := CASE v_week
          WHEN 0 THEN 'Configured switches and documented network topology'
          WHEN 1 THEN 'Set up VLANs and tested inter-VLAN routing'
          WHEN 2 THEN 'Monitored network traffic using Wireshark'
          ELSE 'Deployed firewall rules and security policies'
        END;

        IF NOT EXISTS (SELECT 1 FROM ojt_daily_tasks WHERE student_id = v_s5 AND date = v_date) THEN
          INSERT INTO ojt_daily_tasks (student_id, date, task_description, hours_worked, supervisor_id, status, remarks)
          VALUES (v_s5, v_date, v_task_desc, 8.0, v_super_id, 'Approved', 'Solid performance');
        END IF;
      END IF;

    END IF;
    v_date := v_date + 1;
  END LOOP;
END $$;


-- =====================================================
-- STEP 6: LINK TASKS TO COMPETENCIES
-- =====================================================
DO $$
DECLARE
  v_s1 INT; v_s2 INT; v_s3 INT; v_s4 INT; v_s5 INT;
  v_comp_sd INT; v_comp_ui INT; v_comp_da INT; v_comp_ts INT; v_comp_net INT;
BEGIN
  SELECT user_id INTO v_s1 FROM users WHERE email = 'juancarlo.delacruz@student.cit.edu';
  SELECT user_id INTO v_s2 FROM users WHERE email = 'maria.santos@student.cit.edu';
  SELECT user_id INTO v_s3 FROM users WHERE email = 'rafael.reyes@student.cit.edu';
  SELECT user_id INTO v_s4 FROM users WHERE email = 'patricia.gonzales@student.cit.edu';
  SELECT user_id INTO v_s5 FROM users WHERE email = 'miguel.ramos@student.cit.edu';

  SELECT competency_id INTO v_comp_sd FROM competencies WHERE title = 'Software Development';
  SELECT competency_id INTO v_comp_ui FROM competencies WHERE title = 'User Experience / UI Design';
  SELECT competency_id INTO v_comp_da FROM competencies WHERE title = 'Data Analysis';
  SELECT competency_id INTO v_comp_ts FROM competencies WHERE title = 'Technical Support';
  SELECT competency_id INTO v_comp_net FROM competencies WHERE title = 'Networking';

  -- Link S1 tasks → Software Development
  INSERT INTO task_competencies (task_id, competency_id)
  SELECT t.task_id, v_comp_sd
  FROM ojt_daily_tasks t
  WHERE t.student_id = v_s1
    AND NOT EXISTS (SELECT 1 FROM task_competencies tc WHERE tc.task_id = t.task_id AND tc.competency_id = v_comp_sd);

  -- Link S2 tasks → UI Design
  INSERT INTO task_competencies (task_id, competency_id)
  SELECT t.task_id, v_comp_ui
  FROM ojt_daily_tasks t
  WHERE t.student_id = v_s2
    AND NOT EXISTS (SELECT 1 FROM task_competencies tc WHERE tc.task_id = t.task_id AND tc.competency_id = v_comp_ui);

  -- Link S3 tasks → Data Analysis
  INSERT INTO task_competencies (task_id, competency_id)
  SELECT t.task_id, v_comp_da
  FROM ojt_daily_tasks t
  WHERE t.student_id = v_s3
    AND NOT EXISTS (SELECT 1 FROM task_competencies tc WHERE tc.task_id = t.task_id AND tc.competency_id = v_comp_da);

  -- Link S4 tasks → Technical Support
  INSERT INTO task_competencies (task_id, competency_id)
  SELECT t.task_id, v_comp_ts
  FROM ojt_daily_tasks t
  WHERE t.student_id = v_s4
    AND NOT EXISTS (SELECT 1 FROM task_competencies tc WHERE tc.task_id = t.task_id AND tc.competency_id = v_comp_ts);

  -- Link S5 tasks → Networking
  INSERT INTO task_competencies (task_id, competency_id)
  SELECT t.task_id, v_comp_net
  FROM ojt_daily_tasks t
  WHERE t.student_id = v_s5
    AND NOT EXISTS (SELECT 1 FROM task_competencies tc WHERE tc.task_id = t.task_id AND tc.competency_id = v_comp_net);
END $$;


-- =====================================================
-- STEP 7: EVALUATIONS (1 per student, mid-period)
-- =====================================================
DO $$
DECLARE
  v_super_id INT;
  v_s1 INT; v_s2 INT; v_s3 INT; v_s4 INT; v_s5 INT;
BEGIN
  SELECT user_id INTO v_super_id FROM users WHERE email = 'supervisor.cruz@techpartner.com';
  SELECT user_id INTO v_s1 FROM users WHERE email = 'juancarlo.delacruz@student.cit.edu';
  SELECT user_id INTO v_s2 FROM users WHERE email = 'maria.santos@student.cit.edu';
  SELECT user_id INTO v_s3 FROM users WHERE email = 'rafael.reyes@student.cit.edu';
  SELECT user_id INTO v_s4 FROM users WHERE email = 'patricia.gonzales@student.cit.edu';
  SELECT user_id INTO v_s5 FROM users WHERE email = 'miguel.ramos@student.cit.edu';

  -- S1: Juan Carlo — Excellent
  IF NOT EXISTS (SELECT 1 FROM evaluations WHERE student_id = v_s1 AND evaluation_period_start = '2026-03-20') THEN
    INSERT INTO evaluations (student_id, supervisor_id, criteria, total_score, feedback, evaluation_period_start, evaluation_period_end, status)
    VALUES (v_s1, v_super_id,
      '{"attendance": 95, "technical_skills": 92, "communication": 90, "initiative": 93, "teamwork": 91}'::JSONB,
      92.2, 'Juan Carlo is an outstanding intern. Very proactive and demonstrates strong coding skills. Consistently delivers quality work ahead of schedule.',
      '2026-03-20', '2026-04-10', 'Submitted');
  END IF;

  -- S2: Maria Angela — Great
  IF NOT EXISTS (SELECT 1 FROM evaluations WHERE student_id = v_s2 AND evaluation_period_start = '2026-03-20') THEN
    INSERT INTO evaluations (student_id, supervisor_id, criteria, total_score, feedback, evaluation_period_start, evaluation_period_end, status)
    VALUES (v_s2, v_super_id,
      '{"attendance": 96, "technical_skills": 88, "communication": 94, "initiative": 90, "teamwork": 93}'::JSONB,
      92.2, 'Maria Angela shows excellent design sense and communication. Her UI work significantly improved our product mockups. A valuable team member.',
      '2026-03-20', '2026-04-10', 'Submitted');
  END IF;

  -- S3: Rafael James — Average
  IF NOT EXISTS (SELECT 1 FROM evaluations WHERE student_id = v_s3 AND evaluation_period_start = '2026-03-20') THEN
    INSERT INTO evaluations (student_id, supervisor_id, criteria, total_score, feedback, evaluation_period_start, evaluation_period_end, status)
    VALUES (v_s3, v_super_id,
      '{"attendance": 72, "technical_skills": 80, "communication": 75, "initiative": 70, "teamwork": 78}'::JSONB,
      75.0, 'Rafael has good technical potential but needs to improve punctuality. Frequent tardiness affects his output and team coordination.',
      '2026-03-20', '2026-04-10', 'Submitted');
  END IF;

  -- S4: Patricia Mae — Problematic (fake GPS)
  IF NOT EXISTS (SELECT 1 FROM evaluations WHERE student_id = v_s4 AND evaluation_period_start = '2026-03-20') THEN
    INSERT INTO evaluations (student_id, supervisor_id, criteria, total_score, feedback, evaluation_period_start, evaluation_period_end, status)
    VALUES (v_s4, v_super_id,
      '{"attendance": 45, "technical_skills": 65, "communication": 60, "initiative": 40, "teamwork": 55}'::JSONB,
      53.0, 'Patricia''s attendance records show multiple GPS anomalies flagged by the system. Several attendance entries were rejected due to suspected location spoofing. This is a serious integrity concern that has been reported to the coordinator.',
      '2026-03-20', '2026-04-10', 'Submitted');
  END IF;

  -- S5: Miguel Antonio — Good but absent
  IF NOT EXISTS (SELECT 1 FROM evaluations WHERE student_id = v_s5 AND evaluation_period_start = '2026-03-20') THEN
    INSERT INTO evaluations (student_id, supervisor_id, criteria, total_score, feedback, evaluation_period_start, evaluation_period_end, status)
    VALUES (v_s5, v_super_id,
      '{"attendance": 78, "technical_skills": 87, "communication": 82, "initiative": 84, "teamwork": 86}'::JSONB,
      83.4, 'Miguel demonstrates strong networking skills when present. However, he has missed 3 days during this period. When on-site, his contributions are valuable.',
      '2026-03-20', '2026-04-10', 'Submitted');
  END IF;
END $$;


-- =====================================================
-- STEP 8: AI INSIGHTS (one prediction per student)
-- =====================================================
DO $$
DECLARE
  v_s1 INT; v_s2 INT; v_s3 INT; v_s4 INT; v_s5 INT;
BEGIN
  SELECT user_id INTO v_s1 FROM users WHERE email = 'juancarlo.delacruz@student.cit.edu';
  SELECT user_id INTO v_s2 FROM users WHERE email = 'maria.santos@student.cit.edu';
  SELECT user_id INTO v_s3 FROM users WHERE email = 'rafael.reyes@student.cit.edu';
  SELECT user_id INTO v_s4 FROM users WHERE email = 'patricia.gonzales@student.cit.edu';
  SELECT user_id INTO v_s5 FROM users WHERE email = 'miguel.ramos@student.cit.edu';

  -- S1: Excellent prediction
  INSERT INTO ai_insights (student_id, model_name, insight_type, result, confidence, input_data, model_version)
  VALUES (v_s1, 'OJT-Predictor-v2', 'performance_prediction',
    '{"predicted_performance": "Excellent", "risk_level": "Low", "predicted_grade": "1.25", "completion_probability": 0.98, "strengths": ["punctuality", "technical_skills", "initiative"], "areas_for_improvement": ["documentation"], "recommendation": "Strong candidate for full-time employment offer."}'::JSONB,
    0.94, '{"total_hours": 128, "attendance_rate": 1.0, "avg_trust_score": 97, "task_approval_rate": 1.0}'::JSONB, 'v2.1');

  -- S2: Great prediction
  INSERT INTO ai_insights (student_id, model_name, insight_type, result, confidence, input_data, model_version)
  VALUES (v_s2, 'OJT-Predictor-v2', 'performance_prediction',
    '{"predicted_performance": "Excellent", "risk_level": "Low", "predicted_grade": "1.25", "completion_probability": 0.97, "strengths": ["creativity", "communication", "design_skills"], "areas_for_improvement": ["time_management_on_complex_tasks"], "recommendation": "Outstanding design skills. Should consider UX specialization."}'::JSONB,
    0.92, '{"total_hours": 128, "attendance_rate": 1.0, "avg_trust_score": 95, "task_approval_rate": 1.0}'::JSONB, 'v2.1');

  -- S3: Average prediction
  INSERT INTO ai_insights (student_id, model_name, insight_type, result, confidence, input_data, model_version)
  VALUES (v_s3, 'OJT-Predictor-v2', 'performance_prediction',
    '{"predicted_performance": "Average", "risk_level": "Medium", "predicted_grade": "2.50", "completion_probability": 0.82, "strengths": ["data_analysis", "sql_skills"], "areas_for_improvement": ["punctuality", "consistency"], "recommendation": "Needs attendance improvement plan. Technical skills are adequate but tardiness is a recurring concern."}'::JSONB,
    0.78, '{"total_hours": 112, "attendance_rate": 1.0, "avg_trust_score": 86, "task_approval_rate": 0.80, "late_count": 6}'::JSONB, 'v2.1');

  -- S4: At-risk prediction (FAKE GPS)
  INSERT INTO ai_insights (student_id, model_name, insight_type, result, confidence, input_data, model_version)
  VALUES (v_s4, 'OJT-Predictor-v2', 'performance_prediction',
    '{"predicted_performance": "At Risk", "risk_level": "Critical", "predicted_grade": "4.00", "completion_probability": 0.35, "strengths": [], "areas_for_improvement": ["integrity", "attendance_verification", "on_site_presence"], "recommendation": "CRITICAL: Multiple GPS spoofing incidents detected. 6 out of 16 attendance records rejected. Average trust score is 22/100. Recommend immediate intervention by coordinator. Student may face disciplinary action.", "flags": ["FAKE_GPS_DETECTED", "INTEGRITY_VIOLATION", "PATTERN_ANOMALY"]}'::JSONB,
    0.89, '{"total_hours": 80, "attendance_rate": 0.625, "avg_trust_score": 22, "task_approval_rate": 0.625, "fake_gps_flags": 16, "rejected_days": 6}'::JSONB, 'v2.1');

  -- S5: Good prediction
  INSERT INTO ai_insights (student_id, model_name, insight_type, result, confidence, input_data, model_version)
  VALUES (v_s5, 'OJT-Predictor-v2', 'performance_prediction',
    '{"predicted_performance": "Good", "risk_level": "Low-Medium", "predicted_grade": "1.75", "completion_probability": 0.88, "strengths": ["networking_skills", "technical_aptitude", "teamwork"], "areas_for_improvement": ["attendance_consistency"], "recommendation": "Strong performer when present. 3 absences noted. Should maintain better attendance for remaining OJT period."}'::JSONB,
    0.85, '{"total_hours": 104, "attendance_rate": 0.8125, "avg_trust_score": 94, "task_approval_rate": 1.0, "absent_days": 3}'::JSONB, 'v2.1');
END $$;


-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- Check user counts
SELECT role, COUNT(*) AS count FROM users WHERE email LIKE '%cit.edu' OR email LIKE '%techpartner%' GROUP BY role ORDER BY role;

-- Check attendance per student
SELECT u.full_name, COUNT(a.attendance_id) AS total_records,
       SUM(CASE WHEN a.status = 'Approved' THEN 1 ELSE 0 END) AS approved,
       SUM(CASE WHEN a.status = 'Rejected' THEN 1 ELSE 0 END) AS rejected,
       ROUND(AVG(a.trust_score)::NUMERIC, 1) AS avg_trust,
       SUM(CASE WHEN a.inside_geofence = FALSE THEN 1 ELSE 0 END) AS outside_fence
FROM attendance a
JOIN users u ON a.student_id = u.user_id
WHERE u.email LIKE '%student.cit.edu'
GROUP BY u.full_name
ORDER BY u.full_name;

-- Check tasks per student
SELECT u.full_name, COUNT(t.task_id) AS tasks,
       SUM(CASE WHEN t.status = 'Approved' THEN 1 ELSE 0 END) AS approved_tasks
FROM ojt_daily_tasks t
JOIN users u ON t.student_id = u.user_id
WHERE u.email LIKE '%student.cit.edu'
GROUP BY u.full_name
ORDER BY u.full_name;

-- Check fake GPS flags
SELECT u.full_name, a.date, a.trust_score, a.trust_flags, a.inside_geofence, 
       ROUND(a.distance_m::NUMERIC, 1) AS distance_m, a.status, a.verification_status
FROM attendance a
JOIN users u ON a.student_id = u.user_id
WHERE u.email = 'patricia.gonzales@student.cit.edu'
ORDER BY a.date;

-- Summary view
SELECT '✅ Mock data seed complete!' AS status;
