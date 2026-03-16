-- migration_cleanup_attendance_columns.sql
-- Removes legacy time_in/time_out columns and updates trigger logic to be segment-only

BEGIN;

-- 1. Drop legacy columns from attendance table
ALTER TABLE attendance 
DROP COLUMN IF EXISTS time_in,
DROP COLUMN IF EXISTS time_out;

-- 2. Update the calculate_attendance_hours trigger function
CREATE OR REPLACE FUNCTION calculate_attendance_hours()
RETURNS TRIGGER AS $$
DECLARE
    v_morning_start TIME := '08:00:00';
    v_morning_end   TIME := '12:00:00';
    v_afternoon_start TIME := '13:00:00';
    v_afternoon_end   TIME := '17:00:00';
    
    v_actual_m_in  TIME;
    v_actual_m_out TIME;
    v_actual_a_in  TIME;
    v_actual_a_out TIME;
    
    v_morning_hours   NUMERIC(10, 2) := 0;
    v_afternoon_hours NUMERIC(10, 2) := 0;
    v_deduction_mins  INTEGER := 0;
    v_late_threshold TIME := '08:00:00';
BEGIN
    -- Use segment columns directly
    v_actual_m_in  := NEW.morning_in;
    v_actual_m_out := NEW.morning_out;
    v_actual_a_in  := NEW.afternoon_in;
    v_actual_a_out := NEW.afternoon_out;

    -- MORNING SESSION CALCULATION
    IF v_actual_m_in IS NOT NULL AND v_actual_m_out IS NOT NULL THEN
        -- Apply lateness deduction if arriving after 08:00
        IF v_actual_m_in > v_late_threshold THEN
            -- Calculate 30-min blocks for deduction
            v_deduction_mins := (EXTRACT(EPOCH FROM (v_actual_m_in - v_late_threshold)) / 60)::INTEGER;
            -- Simple rule: every minute late is a minute deducted from regular hours calculation
            -- but the system rounds to 30-min sessions in the existing migration_attendance_rules.sql logic.
            -- Let's stick to the logic in migration_attendance_rules.sql but remove time_in/out.
        END IF;
        
        -- Cap morning at 4 hours
        v_morning_hours := LEAST(4.0, (EXTRACT(EPOCH FROM (v_actual_m_out - GREATEST(v_actual_m_in, v_morning_start))) / 3600.0));
        IF v_morning_hours < 0 THEN v_morning_hours := 0; END IF;
    END IF;

    -- AFTERNOON SESSION CALCULATION
    IF v_actual_a_in IS NOT NULL AND v_actual_a_out IS NOT NULL THEN
        -- Cap afternoon at 4 hours
        v_afternoon_hours := LEAST(4.0, (EXTRACT(EPOCH FROM (v_actual_a_out - GREATEST(v_actual_a_in, v_afternoon_start))) / 3600.0));
        IF v_afternoon_hours < 0 THEN v_afternoon_hours := 0; END IF;
    END IF;

    -- Update NEW record
    NEW.regular_hours := v_morning_hours + v_afternoon_hours;
    NEW.deduction_minutes := v_deduction_mins;
    
    -- Total hours includes overtime if exists
    NEW.total_hours := NEW.regular_hours + COALESCE(NEW.overtime_hours, 0);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Update create_attendance stored procedure
CREATE OR REPLACE FUNCTION create_attendance(
    p_student_id INT,
    p_date DATE,
    p_morning_in TIME DEFAULT NULL,
    p_morning_out TIME DEFAULT NULL,
    p_afternoon_in TIME DEFAULT NULL,
    p_afternoon_out TIME DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_attendance_id INT;
BEGIN
    INSERT INTO attendance (
        student_id, date,
        morning_in, morning_out, afternoon_in, afternoon_out
    )
    VALUES (
        p_student_id, p_date,
        p_morning_in, p_morning_out, p_afternoon_in, p_afternoon_out
    )
    RETURNING attendance_id INTO v_attendance_id;
    
    RETURN jsonb_build_object(
        'success', TRUE,
        'attendance_id', v_attendance_id,
        'message', 'Attendance recorded successfully'
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'errors', ARRAY[SQLERRM],
            'attendance_id', NULL
        );
END;
$$ LANGUAGE plpgsql;

-- 4. Update get_attendance stored procedure
CREATE OR REPLACE FUNCTION get_attendance(p_attendance_id INT)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'attendance_id', a.attendance_id,
        'student_id', a.student_id,
        'student_name', u.full_name,
        'date', a.date,
        'total_hours', a.total_hours,
        'morning_in', a.morning_in,
        'morning_out', a.morning_out,
        'afternoon_in', a.afternoon_in,
        'afternoon_out', a.afternoon_out,
        'overtime_in', a.overtime_in,
        'overtime_out', a.overtime_out,
        'total_hours', a.total_hours,
        'regular_hours', a.regular_hours,
        'overtime_hours', a.overtime_hours,
        'deduction_minutes', a.deduction_minutes,
        'verified', a.verified,
        'status', a.status,
        'created_at', a.created_at
    ) INTO v_result
    FROM attendance a
    JOIN users u ON a.student_id = u.user_id
    WHERE a.attendance_id = p_attendance_id;
    
    RETURN COALESCE(v_result, jsonb_build_object('error', 'Attendance record not found'));
END;
$$ LANGUAGE plpgsql;

-- 5. Update update_attendance stored procedure
CREATE OR REPLACE FUNCTION update_attendance(
    p_attendance_id INT,
    p_morning_in TIME DEFAULT NULL,
    p_morning_out TIME DEFAULT NULL,
    p_afternoon_in TIME DEFAULT NULL,
    p_afternoon_out TIME DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    UPDATE attendance SET
        morning_in = COALESCE(p_morning_in, morning_in),
        morning_out = COALESCE(p_morning_out, morning_out),
        afternoon_in = COALESCE(p_afternoon_in, afternoon_in),
        afternoon_out = COALESCE(p_afternoon_out, afternoon_out),
        updated_at = CURRENT_TIMESTAMP
    WHERE attendance_id = p_attendance_id
    RETURNING jsonb_build_object(
        'success', TRUE,
        'attendance_id', attendance_id,
        'total_hours', total_hours
    ) INTO v_result;
    
    IF v_result IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Attendance record not found'
        );
    END IF;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

COMMIT;
