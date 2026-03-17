-- Migration to add coordinator comments to attendance and daily tasks
-- Date: 2026-03-16

-- Add coordinator comment to attendance
ALTER TABLE attendance ADD COLUMN IF NOT EXISTS coordinator_comment TEXT;
ALTER TABLE attendance ADD COLUMN IF NOT EXISTS coordinator_comment_at TIMESTAMP;
ALTER TABLE attendance ADD COLUMN IF NOT EXISTS checkin_photo_path TEXT;

-- Add coordinator comment to daily tasks (for task-specific feedback)
ALTER TABLE ojt_daily_tasks ADD COLUMN IF NOT EXISTS coordinator_comment TEXT;
ALTER TABLE ojt_daily_tasks ADD COLUMN IF NOT EXISTS coordinator_comment_at TIMESTAMP;

-- Create index for faster lookup of records with comments
CREATE INDEX IF NOT EXISTS idx_attendance_comment ON attendance(student_id) WHERE coordinator_comment IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_daily_tasks_comment ON ojt_daily_tasks(student_id) WHERE coordinator_comment IS NOT NULL;
