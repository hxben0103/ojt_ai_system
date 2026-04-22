-- =====================================================
-- Unified Attendance Hours Calculation Trigger
-- Rule: 1-30 min late = 2-hour deduction
-- =====================================================

CREATE OR REPLACE FUNCTION calculate_attendance_hours()
RETURNS TRIGGER AS $$
DECLARE
    v_morning_start TIME := '08:00:00';
    v_morning_end   TIME := '12:00:00';
    v_afternoon_start TIME := '13:00:00';
    v_afternoon_end   TIME := '17:00:00';
    
    v_morning_hours   NUMERIC(5, 2) := 0;
    v_afternoon_hours NUMERIC(5, 2) := 0;
    v_overtime_hours  NUMERIC(5, 2) := 0;
    
    v_morning_late_mins INTEGER := 0;
    v_afternoon_late_mins INTEGER := 0;
    v_total_deduction_mins INTEGER := 0;
    
    v_day_of_week INTEGER;
BEGIN
    -- 1. Reset/Initialize tracking fields
    NEW.deduction_minutes := 0;
    NEW.regular_hours := 0;
    NEW.overtime_hours := 0;
    NEW.total_hours := 0;

    v_day_of_week := EXTRACT(DOW FROM NEW.date);

    -- 2. REGULAR HOURS CALCULATION (Monday to Friday only)
    IF v_day_of_week > 0 AND v_day_of_week < 6 THEN
        
        -- --- MORNING SESSION ---
        IF NEW.morning_in IS NOT NULL AND NEW.morning_out IS NOT NULL THEN
            -- Lateness check (after 08:00)
            IF NEW.morning_in > v_morning_start THEN
                v_morning_late_mins := FLOOR(EXTRACT(EPOCH FROM (NEW.morning_in - v_morning_start)) / 60);
                -- Rule: 1-30 min = 120 mins (2hr) deduction
                v_total_deduction_mins := v_total_deduction_mins + (CEIL(v_morning_late_mins / 30.0) * 120);
            END IF;

            -- Credit calculation (Baseline 4.0 hours)
            -- Subtract penalty: 1-30m late = -2.0h
            v_morning_hours := 4.0 - (CEIL(v_morning_late_mins / 30.0) * 2.0);
            
            -- Subtract time if clocking out before 12:00
            IF NEW.morning_out < v_morning_end THEN
                v_morning_hours := v_morning_hours - (EXTRACT(EPOCH FROM (v_morning_end - NEW.morning_out)) / 3600.0);
            END IF;
            
            -- Clamp at 0
            v_morning_hours := GREATEST(0, v_morning_hours);
        END IF;

        -- --- AFTERNOON SESSION ---
        IF NEW.afternoon_in IS NOT NULL AND NEW.afternoon_out IS NOT NULL THEN
            -- Lateness check (after 13:00)
            IF NEW.afternoon_in > v_afternoon_start THEN
                v_afternoon_late_mins := FLOOR(EXTRACT(EPOCH FROM (NEW.afternoon_in - v_afternoon_start)) / 60);
                v_total_deduction_mins := v_total_deduction_mins + (CEIL(v_afternoon_late_mins / 30.0) * 120);
            END IF;

            -- Credit calculation (Baseline 4.0 hours)
            v_afternoon_hours := 4.0 - (CEIL(v_afternoon_late_mins / 30.0) * 2.0);
            
            -- Subtract time if clocking out before 17:00
            IF NEW.afternoon_out < v_afternoon_end THEN
                v_afternoon_hours := v_afternoon_hours - (EXTRACT(EPOCH FROM (v_afternoon_end - NEW.afternoon_out)) / 3600.0);
            END IF;
            
            -- Clamp at 0
            v_afternoon_hours := GREATEST(0, v_afternoon_hours);
        END IF;

    END IF;

    -- 3. OVERTIME SESSION (Available every day)
    IF NEW.overtime_in IS NOT NULL AND NEW.overtime_out IS NOT NULL THEN
        v_overtime_hours := EXTRACT(EPOCH FROM (NEW.overtime_out - NEW.overtime_in)) / 3600.0;
        v_overtime_hours := GREATEST(0, v_overtime_hours);
    END IF;

    -- 4. FINALIZE FIELDS
    NEW.deduction_minutes := v_total_deduction_mins;
    NEW.regular_hours := LEAST(8.0, v_morning_hours + v_afternoon_hours);
    NEW.overtime_hours := v_overtime_hours;
    NEW.total_hours := NEW.regular_hours + NEW.overtime_hours;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Re-apply trigger to ensuring one canonical version
DROP TRIGGER IF EXISTS calculate_attendance_hours_trigger ON attendance;
CREATE TRIGGER calculate_attendance_hours_trigger
BEFORE INSERT OR UPDATE ON attendance
FOR EACH ROW EXECUTE FUNCTION calculate_attendance_hours();
