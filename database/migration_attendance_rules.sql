-- =====================================================
-- Migration: Add deduction_minutes and strictly enforce attendance rounding rules
-- =====================================================

-- 1. Add new tracking columns safely
ALTER TABLE attendance 
ADD COLUMN IF NOT EXISTS deduction_minutes INT DEFAULT 0,
ADD COLUMN IF NOT EXISTS regular_hours NUMERIC(5,2) DEFAULT 0.00;

-- 2. Drop the old trigger so we can replace it safely
DROP TRIGGER IF EXISTS calculate_attendance_hours_trigger ON attendance;

-- 3. Replace the calculation logic entirely
CREATE OR REPLACE FUNCTION calculate_attendance_hours()
RETURNS TRIGGER AS $$
DECLARE
    v_morning_start TIME := '08:00:00';
    v_morning_end TIME := '12:00:00';
    v_afternoon_start TIME := '13:00:00';
    v_afternoon_end TIME := '17:00:00';
    
    v_morning_credit NUMERIC(5,2) := 0;
    v_afternoon_credit NUMERIC(5,2) := 0;
    
    v_morning_late INT := 0;
    v_afternoon_late INT := 0;
    v_total_deduction INT := 0;
    
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

    -- Check for weekends (0=Sunday, 6=Saturday)
    -- If weekend, standard logic yields 0 regular hours. 
    -- Overtime handling would be separate if implemented.
    v_day_of_week := EXTRACT(DOW FROM NEW.date);
    IF v_day_of_week = 0 OR v_day_of_week = 6 THEN
        RETURN NEW;
    END IF;

    -- Map segment logs (if available) or fallback to basic time_in/time_out
    v_actual_m_in := COALESCE(NEW.morning_in, NEW.time_in);
    v_actual_m_out := COALESCE(NEW.morning_out, CASE WHEN NEW.time_out <= v_morning_end THEN NEW.time_out ELSE NULL END);
    v_actual_a_in := COALESCE(NEW.afternoon_in, CASE WHEN NEW.time_in >= v_afternoon_start THEN NEW.time_in ELSE NULL END);
    v_actual_a_out := COALESCE(NEW.afternoon_out, NEW.time_out);

    -- =========================================
    -- MORNING SESSION CALCULATION
    -- =========================================
    IF v_actual_m_in IS NOT NULL AND v_actual_m_out IS NOT NULL THEN
        -- 1. Cap end time (No extra credit beyond 12:00)
        IF v_actual_m_out > v_morning_end THEN
            v_actual_m_out := v_morning_end;
        END IF;

        -- 2. Cap start time (No extra credit before 8:00)
        IF v_actual_m_in < v_morning_start THEN
            v_actual_m_in := v_morning_start;
        END IF;

        -- 3. Calculate Morning Late Minutes
        IF v_actual_m_in > v_morning_start THEN
            v_morning_late := GREATEST(0, FLOOR(EXTRACT(EPOCH FROM (v_actual_m_in - v_morning_start)) / 60));
        END IF;

        -- 4. Calculate deduction in 30 min blocks
        -- 1-30 mins = 30 min deduction, 31-60 = 60 min deduction, etc.
        IF v_morning_late > 0 THEN
            v_total_deduction := v_total_deduction + (CEIL(v_morning_late / 30.0) * 30);
        END IF;
        
        -- 5. Calculate Morning Raw Credit
        IF v_actual_m_out > v_actual_m_in THEN
           v_morning_credit := GREATEST(0, (EXTRACT(EPOCH FROM (v_actual_m_out - v_morning_start)) / 3600.0) - (CEIL(v_morning_late / 30.0) * 0.5));
           -- Max morning credit is 4.0
           v_morning_credit := LEAST(4.0, v_morning_credit);
        END IF;
    END IF;

    -- =========================================
    -- AFTERNOON SESSION CALCULATION
    -- =========================================
    IF v_actual_a_in IS NOT NULL AND v_actual_a_out IS NOT NULL THEN
        -- 1. Cap end time (No extra credit beyond 17:00)
        IF v_actual_a_out > v_afternoon_end THEN
            v_actual_a_out := v_afternoon_end;
        END IF;

        -- 2. Cap start time (No extra credit before 13:00)
        IF v_actual_a_in < v_afternoon_start THEN
            v_actual_a_in := v_afternoon_start;
        END IF;

        -- 3. Calculate Afternoon Late Minutes
        IF v_actual_a_in > v_afternoon_start THEN
            v_afternoon_late := GREATEST(0, FLOOR(EXTRACT(EPOCH FROM (v_actual_a_in - v_afternoon_start)) / 60));
        END IF;

        -- 4. Calculate deduction in 30 min blocks
        IF v_afternoon_late > 0 THEN
            v_total_deduction := v_total_deduction + (CEIL(v_afternoon_late / 30.0) * 30);
        END IF;
        
        -- 5. Calculate Afternoon Raw Credit
        IF v_actual_a_out > v_actual_a_in THEN
           v_afternoon_credit := GREATEST(0, (EXTRACT(EPOCH FROM (v_actual_a_out - v_afternoon_start)) / 3600.0) - (CEIL(v_afternoon_late / 30.0) * 0.5));
           -- Max afternoon credit is 4.0
           v_afternoon_credit := LEAST(4.0, v_afternoon_credit);
        END IF;
    END IF;

    -- =========================================
    -- FINALIZE
    -- =========================================
    NEW.deduction_minutes := v_total_deduction;
    NEW.regular_hours := LEAST(8.0, v_morning_credit + v_afternoon_credit);
    
    -- In this system, total_hours tracks the credited hours applied to progress
    NEW.total_hours := NEW.regular_hours; 

    -- If there's an explicit overtime log (system extension)
    IF NEW.overtime_in IS NOT NULL AND NEW.overtime_out IS NOT NULL THEN
        NEW.total_hours := NEW.total_hours + (EXTRACT(EPOCH FROM (NEW.overtime_out - NEW.overtime_in)) / 3600.0);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER calculate_attendance_hours_trigger
BEFORE INSERT OR UPDATE ON attendance
FOR EACH ROW EXECUTE FUNCTION calculate_attendance_hours();
