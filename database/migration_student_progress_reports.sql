-- ========== STUDENT PROGRESS REPORTS ==========
-- Students upload weekly progress reports (WPR) for evaluation
CREATE TABLE IF NOT EXISTS student_progress_reports (
    report_id SERIAL PRIMARY KEY,
    student_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    file_path TEXT NOT NULL,
    file_name VARCHAR(255),
    status VARCHAR(20) DEFAULT 'Pending', -- Pending, Reviewed, Approved, Rejected
    feedback TEXT,
    week_number INT,
    report_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Trigger to update updated_at
CREATE TRIGGER update_student_progress_reports_updated_at
BEFORE UPDATE ON student_progress_reports
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Index for performance
CREATE INDEX IF NOT EXISTS idx_student_reports_student_id ON student_progress_reports(student_id);
CREATE INDEX IF NOT EXISTS idx_student_reports_status ON student_progress_reports(status);
