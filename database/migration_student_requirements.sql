-- Migration: Student Requirements Table
-- Description: Tracks completion status of OJT application requirements

CREATE TABLE IF NOT EXISTS student_requirements (
    id SERIAL PRIMARY KEY,
    student_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    requirement_name VARCHAR(255) NOT NULL,
    status VARCHAR(20) DEFAULT 'Lacking', -- 'Completed' or 'Lacking'
    file_path TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(student_id, requirement_name)
);

-- Index for faster lookups by student
CREATE INDEX IF NOT EXISTS idx_student_requirements_student_id ON student_requirements(student_id);

-- Optional: Function to initialize requirements for a student
CREATE OR REPLACE FUNCTION initialize_student_requirements(target_student_id INT)
RETURNS VOID AS $$
BEGIN
    INSERT INTO student_requirements (student_id, requirement_name)
    VALUES 
        (target_student_id, 'Application Letter (signed)'),
        (target_student_id, 'Comprehensive Resume (with photo & skills)'),
        (target_student_id, 'Recommendation Letter (from Coordinator)'),
        (target_student_id, 'Draft Memorandum of Agreement (MOA)'),
        (target_student_id, 'Application Letter - Submitted to HTE'),
        (target_student_id, 'Resume - Submitted to HTE'),
        (target_student_id, 'Recommendation Letter - Submitted to HTE'),
        (target_student_id, 'Draft MOA - Submitted to HTE'),
        (target_student_id, 'Accepted Recommendation Letter (from HTE)'),
        (target_student_id, 'Accepted or Revised MOA (from HTE)'),
        (target_student_id, 'Final MOA (5 copies)'),
        (target_student_id, 'Proof of Notarization Payment'),
        (target_student_id, 'Parent''s Consent and Waiver'),
        (target_student_id, 'Medical Certificate (Fit to Work)'),
        (target_student_id, 'Pregnancy Test (for female students)'),
        (target_student_id, 'OB-GYN Certificate (if applicable)'),
        (target_student_id, 'Chest X-ray'),
        (target_student_id, 'Hepatitis B Test'),
        (target_student_id, 'Blood Type Test'),
        (target_student_id, 'Urinalysis'),
        (target_student_id, 'Complete Blood Count (CBC)')
    ON CONFLICT (student_id, requirement_name) DO NOTHING;
END;
$$ LANGUAGE plpgsql;
