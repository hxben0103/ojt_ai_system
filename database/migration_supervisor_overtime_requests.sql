-- Migration: Replace overtime_requests with supervisor_overtime_requests
-- Drop the old individual-student table
DROP TABLE IF EXISTS overtime_requests;

-- Create the new batch/formal-letter table
CREATE TABLE IF NOT EXISTS supervisor_overtime_requests (
    request_id   SERIAL PRIMARY KEY,
    supervisor_id INTEGER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    coordinator_id INTEGER REFERENCES users(user_id) ON DELETE SET NULL,
    date         DATE NOT NULL,
    student_ids  INTEGER[] NOT NULL,          -- batch of student user_ids
    formal_letter TEXT NOT NULL DEFAULT '',   -- formal request letter text
    status       VARCHAR(20) DEFAULT 'Pending',  -- Pending | Approved | Rejected
    coordinator_remarks TEXT,                 -- optional remarks from coordinator
    created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Fast lookups for coordinators reviewing pending requests
CREATE INDEX IF NOT EXISTS idx_sup_ot_requests_status
  ON supervisor_overtime_requests(status);

-- Fast lookups for a supervisor's own submissions
CREATE INDEX IF NOT EXISTS idx_sup_ot_requests_supervisor
  ON supervisor_overtime_requests(supervisor_id);
