-- =====================================================
-- PostgreSQL Database Schema: Intelligent AI-Powered OJT Monitoring System
-- =====================================================

-- ========== USERS ==========
CREATE TABLE IF NOT EXISTS users (
    user_id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role VARCHAR(20) CHECK (role IN ('Admin', 'Coordinator', 'Supervisor', 'Student')),
    status VARCHAR(20) DEFAULT 'Active',
    date_created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    student_id VARCHAR(50),
    course VARCHAR(100),
    age INTEGER,
    gender VARCHAR(20),
    contact_number VARCHAR(20),
    address TEXT,
    profile_photo TEXT,
    required_hours INTEGER DEFAULT 300
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

-- ========== OJT RECORDS ==========
CREATE TABLE IF NOT EXISTS ojt_records (
    record_id SERIAL PRIMARY KEY,
    student_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    company_name VARCHAR(100),
    coordinator_id INT NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
    supervisor_id INT NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
    start_date DATE,
    end_date DATE,
    status VARCHAR(20) DEFAULT 'Ongoing',
    required_hours INTEGER DEFAULT 300,
    company_address TEXT,
    company_contact VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ========== ATTENDANCE ==========
CREATE TABLE IF NOT EXISTS attendance (
    attendance_id SERIAL PRIMARY KEY,
    student_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    date DATE DEFAULT CURRENT_DATE,
    time_in TIME,
    time_out TIME,
    total_hours NUMERIC(5,2),
    morning_in TIME,
    morning_out TIME,
    afternoon_in TIME,
    afternoon_out TIME,
    overtime_in TIME,
    overtime_out TIME,
    attendance_image TEXT,
    signature TEXT,
    verified BOOLEAN DEFAULT FALSE,
    verified_by INT REFERENCES users(user_id),
    verified_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ========== EVALUATIONS ==========
CREATE TABLE IF NOT EXISTS evaluations (
    eval_id SERIAL PRIMARY KEY,
    student_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    supervisor_id INT NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
    criteria JSONB NOT NULL,
    total_score NUMERIC(5,2),
    feedback TEXT,
    date_evaluated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    evaluation_period_start DATE,
    evaluation_period_end DATE,
    status VARCHAR(20) DEFAULT 'Draft',
    approved_by INT REFERENCES users(user_id),
    approved_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ========== AI INSIGHTS ==========
CREATE TABLE IF NOT EXISTS ai_insights (
    insight_id SERIAL PRIMARY KEY,
    student_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    model_name VARCHAR(50) NOT NULL,
    insight_type VARCHAR(50) NOT NULL,
    result JSONB NOT NULL,
    confidence NUMERIC(4,2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    input_data JSONB,
    model_version VARCHAR(20),
    processing_time_ms INTEGER
);

-- ========== CHATBOT LOGS ==========
CREATE TABLE IF NOT EXISTS chatbot_logs (
    chat_id SERIAL PRIMARY KEY,
    user_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    query TEXT NOT NULL,
    response TEXT NOT NULL,
    model_used VARCHAR(50) NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ========== SYSTEM REPORTS ==========
CREATE TABLE IF NOT EXISTS system_reports (
    report_id SERIAL PRIMARY KEY,
    report_type VARCHAR(50) NOT NULL,
    generated_by INT NOT NULL REFERENCES users(user_id) ON DELETE RESTRICT,
    content JSONB NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    report_period_start DATE,
    report_period_end DATE,
    file_path TEXT,
    status VARCHAR(20) DEFAULT 'Generated'
);

-- =====================================================
-- TRIGGERS
-- =====================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_ojt_records_updated_at
BEFORE UPDATE ON ojt_records
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_attendance_updated_at
BEFORE UPDATE ON attendance
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_evaluations_updated_at
BEFORE UPDATE ON evaluations
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Auto-calculate total hours in attendance
CREATE OR REPLACE FUNCTION calculate_attendance_hours()
RETURNS TRIGGER AS $$
DECLARE
    total NUMERIC(5,2) := 0;
BEGIN
    IF NEW.morning_in IS NOT NULL AND NEW.morning_out IS NOT NULL THEN
        total := total + EXTRACT(EPOCH FROM (NEW.morning_out - NEW.morning_in)) / 3600;
    END IF;
    IF NEW.afternoon_in IS NOT NULL AND NEW.afternoon_out IS NOT NULL THEN
        total := total + EXTRACT(EPOCH FROM (NEW.afternoon_out - NEW.afternoon_in)) / 3600;
    END IF;
    IF NEW.overtime_in IS NOT NULL AND NEW.overtime_out IS NOT NULL THEN
        total := total + EXTRACT(EPOCH FROM (NEW.overtime_out - NEW.overtime_in)) / 3600;
    END IF;
    IF total > 0 THEN
        NEW.total_hours := total;
    ELSIF NEW.time_in IS NOT NULL AND NEW.time_out IS NOT NULL THEN
        NEW.total_hours := EXTRACT(EPOCH FROM (NEW.time_out - NEW.time_in)) / 3600;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER calculate_attendance_hours_trigger
BEFORE INSERT OR UPDATE ON attendance
FOR EACH ROW EXECUTE FUNCTION calculate_attendance_hours();

-- =====================================================
-- VIEWS
-- =====================================================

-- 1️⃣ Active Students
CREATE OR REPLACE VIEW view_active_students AS
SELECT 
    u.user_id,
    u.full_name,
    u.student_id,
    u.course,
    u.email,
    u.contact_number,
    o.record_id,
    o.company_name,
    o.status,
    o.required_hours,
    o.start_date,
    o.end_date
FROM users u
JOIN ojt_records o ON u.user_id = o.student_id
WHERE o.status = 'Ongoing' AND u.role = 'Student';

-- 2️⃣ Attendance Summary
CREATE OR REPLACE VIEW view_attendance_summary AS
SELECT 
    u.user_id,
    u.full_name,
    u.student_id,
    u.course,
    COUNT(DISTINCT a.date) AS total_days,
    SUM(a.total_hours) AS total_hours,
    AVG(a.total_hours) AS avg_hours_per_day,
    SUM(CASE WHEN a.verified THEN 1 ELSE 0 END) AS verified_days,
    MIN(a.date) AS first_attendance_date,
    MAX(a.date) AS last_attendance_date
FROM attendance a
JOIN users u ON a.student_id = u.user_id
GROUP BY u.user_id, u.full_name, u.student_id, u.course;

-- 3️⃣ AI Performance Insights
CREATE OR REPLACE VIEW view_ai_performance AS
SELECT 
    u.user_id,
    u.full_name,
    u.student_id,
    u.course,
    e.total_score AS evaluation_score,
    e.date_evaluated,
    ai.insight_type,
    ai.model_name,
    ai.result->>'predicted_performance' AS prediction,
    ai.result->>'risk_level' AS risk_level,
    ai.confidence,
    ai.created_at AS insight_date
FROM users u
LEFT JOIN evaluations e ON u.user_id = e.student_id
LEFT JOIN ai_insights ai ON u.user_id = ai.student_id
WHERE u.role = 'Student'
ORDER BY ai.created_at DESC;

-- 4️⃣ Student Progress Overview
CREATE OR REPLACE VIEW view_student_progress AS
SELECT 
    u.user_id,
    u.full_name,
    u.student_id,
    u.course,
    o.company_name,
    o.required_hours,
    COALESCE(SUM(a.total_hours), 0) AS completed_hours,
    ROUND((COALESCE(SUM(a.total_hours), 0)::NUMERIC / NULLIF(o.required_hours, 0) * 100), 2) AS completion_percentage,
    COUNT(DISTINCT a.date) AS attendance_days,
    COUNT(DISTINCT e.eval_id) AS evaluation_count,
    AVG(e.total_score) AS avg_evaluation_score,
    COUNT(DISTINCT ai.insight_id) AS ai_insight_count,
    o.start_date,
    o.end_date,
    o.status
FROM users u
JOIN ojt_records o ON u.user_id = o.student_id
LEFT JOIN attendance a ON u.user_id = a.student_id
LEFT JOIN evaluations e ON u.user_id = e.student_id
LEFT JOIN ai_insights ai ON u.user_id = ai.student_id
WHERE u.role = 'Student'
GROUP BY 
    u.user_id, u.full_name, u.student_id, u.course,
    o.company_name, o.required_hours, o.start_date, o.end_date, o.status;

-- 5️⃣ Reports Summary
CREATE OR REPLACE VIEW view_reports_summary AS
SELECT 
    r.report_id,
    r.report_type,
    r.status,
    u.full_name AS generated_by,
    r.created_at,
    r.report_period_start,
    r.report_period_end,
    r.file_path
FROM system_reports r
JOIN users u ON r.generated_by = u.user_id;

-- =====================================================
-- END
-- =====================================================
