-- Performance Indexing for Supervisor Dashboard
-- Target tables: evaluations, ai_insights, ojt_records

-- Index for fast lookup of latest evaluations per student
CREATE INDEX IF NOT EXISTS idx_evaluations_student_supervisor_latest 
ON evaluations(student_id, supervisor_id, date_evaluated DESC);

-- Index for fast lookup of latest AI insights per student
CREATE INDEX IF NOT EXISTS idx_ai_insights_student_latest 
ON ai_insights(student_id, created_at DESC);

-- Index for filtering active students for a supervisor
CREATE INDEX IF NOT EXISTS idx_ojt_records_supervisor_active 
ON ojt_records(supervisor_id, status);

-- Index for attendance lookups by supervisor + date (via join)
CREATE INDEX IF NOT EXISTS idx_attendance_student_date 
ON attendance(student_id, date);
