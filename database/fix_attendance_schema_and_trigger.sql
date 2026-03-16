-- Add missing tracking columns and update trigger for accurate calculation
ALTER TABLE attendance 
ADD COLUMN IF NOT EXISTS overtime_hours NUMERIC(5,2) DEFAULT 0.00;

-- Update the calculation logic
CREATE OR REPLACE FUNCTION calculate_attendance_hours()
RETURNS TRIGGER AS $$
DECLARE
    v_morning_start TIME := '08:00:00';
    v_morning_late_threshold TIME := '08:00:00'; -- Changed from 8:15 to match user request
    v_morning_end TIME := '12:00:00';
    v_afternoon_start TIME := '13:00:00';
    v_afternoon_end TIME := '17:00:00';
    
    v_morning_hours NUMERIC(5,2) := 0;
    v_afternoon_hours NUMERIC(5,2) := 0;
    v_overtime_hours NUMERIC(5,2) := 0;
    
    v_morning_late_mins INT := 0;
    v_afternoon_late_mins INT := 0;
    
    v_actual_m_in TIME;
    v_actual_m_out TIME;
    v_actual_a_in TIME;
    v_actual_a_out TIME;
    
    v_day_of_week INT;
BEGIN
    -- Reset fields
    NEW.deduction_minutes := 0;
    NEW.total_hours := 0;
    NEW.regular_hours := 0;
    NEW.overtime_hours := 0;

    -- Check for weekends (0=Sunday, 6=Saturday)
    v_day_of_week := EXTRACT(DOW FROM NEW.date);
    -- If weekend, we still allow overtime but skip regular hours logic
    -- Unless the system should block weekend attendance entirely.
    -- For now, we follow the user's weekday-only regular hours rule.

    -- Map segment logs
    v_actual_m_in := NEW.morning_in;
    v_actual_m_out := NEW.morning_out;
    v_actual_a_in := NEW.afternoon_in;
    v_actual_a_out := NEW.afternoon_out;

    -- =========================================
    -- MORNING SESSION (WEEKDAYS ONLY)
    -- =========================================
    IF v_day_of_week > 0 AND v_day_of_week < 6 THEN
        IF v_actual_m_in IS NOT NULL AND v_actual_m_out IS NOT NULL THEN
            -- Calculate Lateness
            IF v_actual_m_in > v_morning_late_threshold THEN
                v_morning_late_mins := FLOOR(EXTRACT(EPOCH FROM (v_actual_m_in - v_morning_late_threshold)) / 60);
                -- 30-min block deduction
                NEW.deduction_minutes := NEW.deduction_minutes + (CEIL(v_morning_late_mins / 30.0) * 30);
            END IF;

            -- Calculate Morning Credit (Capped at 8:00 start, 12:00 end)
            v_morning_hours := LEAST(4.0, (EXTRACT(EPOCH FROM (v_actual_m_out - GREATEST(v_actual_m_in, v_morning_start))) / 3600.0));
            -- Apply deduction
            v_morning_hours := GREATEST(0, v_morning_hours - (CEIL(v_morning_late_mins / 30.0) * 0.5));
        END IF;

        -- =========================================
        -- AFTERNOON SESSION (WEEKDAYS ONLY)
        -- =========================================
        IF v_actual_a_in IS NOT NULL AND v_actual_a_out IS NOT NULL THEN
            -- Calculate Afternoon Lateness
            IF v_actual_a_in > v_afternoon_start THEN
                v_afternoon_late_mins := FLOOR(EXTRACT(EPOCH FROM (v_actual_a_in - v_afternoon_start)) / 60);
                NEW.deduction_minutes := NEW.deduction_minutes + (CEIL(v_afternoon_late_mins / 30.0) * 30);
            END IF;

            -- Calculate Afternoon Credit (Capped at 13:00 start, 17:00 end)
            v_afternoon_hours := LEAST(4.0, (EXTRACT(EPOCH FROM (v_actual_a_out - GREATEST(v_actual_a_in, v_afternoon_start))) / 3600.0));
            -- Apply deduction
            v_afternoon_hours := GREATEST(0, v_afternoon_hours - (CEIL(v_afternoon_late_mins / 30.0) * 0.5));
        END IF;
    END IF;

    -- =========================================
    -- OVERTIME SESSION (ALL DAYS)
    -- =========================================
    IF NEW.overtime_in IS NOT NULL AND NEW.overtime_out IS NOT NULL THEN
        v_overtime_hours := EXTRACT(EPOCH FROM (NEW.overtime_out - NEW.overtime_in)) / 3600.0;
    END IF;

    -- Finalize
    NEW.regular_hours := LEAST(8.0, v_morning_hours + v_afternoon_hours);
    NEW.overtime_hours := v_overtime_hours;
    NEW.total_hours := NEW.regular_hours + NEW.overtime_hours;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
