-- =====================================================
-- Migration: Add evaluation_type to evaluations table
-- 
-- Run this once in your Supabase SQL Editor.
--
-- evaluation_type values:
--   'WPR' - Weekly Progress Report   (20% of final grade, submitted weekly, includes attendance)
--   'NR'  - Narrative Report         (20% of final grade, submitted at end of OJT)
--   'CE'  - Coordinator Evaluation   (20% of final grade, given by OJT Coordinator)
--   'SE'  - Supervisor Evaluation    (40% of final grade, given by industry Supervisor on last day)
-- =====================================================

-- Step 1: Add the evaluation_type column (nullable first for backward compatibility)
ALTER TABLE evaluations
  ADD COLUMN IF NOT EXISTS evaluation_type VARCHAR(10)
    CHECK (evaluation_type IN ('WPR', 'NR', 'CE', 'SE'));

-- Step 2: Back-fill existing rows using the submitter's role
--   Existing coordinator-submitted evaluations → CE
--   Existing supervisor-submitted evaluations  → SE
--   All others (no role match)                → NR (best guess for legacy data)
UPDATE evaluations e
SET evaluation_type = CASE
  WHEN u.role = 'Coordinator' THEN 'CE'
  WHEN u.role = 'Supervisor'  THEN 'SE'
  ELSE 'NR'
END
FROM users u
WHERE e.supervisor_id = u.user_id
  AND e.evaluation_type IS NULL;

-- Step 3: Create an index for fast filtering in prediction queries
CREATE INDEX IF NOT EXISTS idx_evaluations_type
  ON evaluations(student_id, evaluation_type);

-- Verify the migration
SELECT evaluation_type, COUNT(*) AS count
FROM evaluations
GROUP BY evaluation_type
ORDER BY evaluation_type;
