-- Migration: Fix Double Attendance Error
-- This script adds a unique constraint to the attendance table and cleans up any duplicates.

BEGIN;

-- 1. Remove Any Accidental Duplicates
-- Keep only the oldest record (based on attendance_id) for each student/date grouping
DELETE FROM attendance
WHERE attendance_id IN (
    SELECT attendance_id
    FROM (
        SELECT attendance_id,
               ROW_NUMBER() OVER (PARTITION BY student_id, date ORDER BY attendance_id ASC) as row_num
        FROM attendance
    ) t
    WHERE t.row_num > 1
);

-- 2. Add Unique Constraint
-- This is the "Safety Wall" that prevents race conditions at the database level
ALTER TABLE attendance 
DROP CONSTRAINT IF EXISTS unique_student_date_attendance;

ALTER TABLE attendance 
ADD CONSTRAINT unique_student_date_attendance UNIQUE (student_id, date);

COMMIT;
