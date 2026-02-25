-- =====================================================
-- Seed Data: OJT Competencies
-- =====================================================
-- This file seeds the competencies table with the official
-- OJT competencies and their point values.

-- Insert competencies (using INSERT ... ON CONFLICT to avoid duplicates)
INSERT INTO competencies (title, point_value) VALUES
('Software Development', 98),
('Machine Learning Engineering', 98),
('IT-Related Research', 98),
('User Experience / UI Design', 98),
('Information Security Analysis', 92),
('Networking', 92),
('Technical Support', 92),
('Data Analysis', 92),
('Customer Service', 86),
('Data Entry and Management', 86),
('Office Work', 86)
ON CONFLICT (title) DO UPDATE SET point_value = EXCLUDED.point_value;

-- Verify insert
SELECT competency_id, title, point_value 
FROM competencies 
ORDER BY point_value DESC, title;

