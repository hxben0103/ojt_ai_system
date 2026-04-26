-- Migration: Create overtime_requests table
CREATE TABLE IF NOT EXISTS overtime_requests (
    request_id SERIAL PRIMARY KEY,
    student_id INTEGER REFERENCES users(user_id) ON DELETE CASCADE,
    supervisor_id INTEGER REFERENCES users(user_id) ON DELETE SET NULL,
    date DATE NOT NULL,
    status VARCHAR(20) DEFAULT 'Pending', -- 'Pending', 'Approved', 'Rejected'
    reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(student_id, date)
);

-- Index for faster supervisor queries
CREATE INDEX IF NOT EXISTS idx_overtime_requests_supervisor ON overtime_requests(supervisor_id, status);
