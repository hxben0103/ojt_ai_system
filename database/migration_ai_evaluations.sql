CREATE TABLE IF NOT EXISTS ai_evaluations (
    id SERIAL PRIMARY KEY,
    student_id INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
    predicted_risk VARCHAR(20),
    progress_score NUMERIC(5,2),
    integrity_score NUMERIC(5,2),
    flags_caught JSONB,
    actual_outcome VARCHAR(50) DEFAULT 'Pending',
    manually_verified_flags JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
