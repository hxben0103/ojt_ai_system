-- =====================================================
-- MIGRATION: V5 Unified Timing & Attendance Logic (FIXED)
-- Goal: Standardize hour calculations and lateness penalties
-- Fix: Removed references to deleted time_in/time_out columns
-- =====================================================

CREATE OR REPLACE FUNCTION calculate_attendance_hours()
RETURNS TRIGGER AS $$
DECLARE
    v_total_hours NUMERIC(5,2) := 0;
    v_regular_hours NUMERIC(5,2) := 0;
    v_overtime_hours NUMERIC(5,2) := 0;
    v_deduction_mins INT := 0;
    
    -- Morning Baselines
    v_m_start TIME := '08:00:00';
    v_m_end   TIME := '12:00:00';
    -- Afternoon Baselines
    v_a_start TIME := '13:00:00';
    v_a_end   TIME := '17:00:00';
    
    v_is_weekend BOOLEAN;
    v_segment_credit NUMERIC(5,2);
    v_late_mins INT;
BEGIN
    -- 1. Check if it is a weekend (0=Sun, 6=Sat)
    v_is_weekend := EXTRACT(DOW FROM NEW.date) IN (0, 6);

    -- 2. RESET TOTALS
    v_regular_hours := 0;
    v_overtime_hours := 0;
    v_deduction_mins := 0;

    -- 3. MORNING SEGMENT (Only on Weekdays)
    IF NOT v_is_weekend AND NEW.morning_in IS NOT NULL AND NEW.morning_out IS NOT NULL THEN
        -- Calculate lateness from baseline
        v_late_mins := GREATEST(0, EXTRACT(EPOCH FROM (NEW.morning_in::time - v_m_start)) / 60)::INT;
        IF v_late_mins > 0 THEN
            v_deduction_mins := v_deduction_mins + v_late_mins;
        END IF;

        -- Calculate raw credit (capped at 4 hours)
        -- Baseline: 08:00 to 12:00
        -- Formula: (MorningOut - MorningStart) - (LatePenalty)
        v_segment_credit := EXTRACT(EPOCH FROM (LEAST(NEW.morning_out::time, v_m_end) - v_m_start)) / 3600.0;
        v_segment_credit := v_segment_credit - (CEIL(v_late_mins / 30.0) * 0.5);
        
        v_regular_hours := v_regular_hours + GREATEST(0, v_segment_credit);
    END IF;

    -- 4. AFTERNOON SEGMENT (Only on Weekdays)
    IF NOT v_is_weekend AND NEW.afternoon_in IS NOT NULL AND NEW.afternoon_out IS NOT NULL THEN
        v_late_mins := GREATEST(0, EXTRACT(EPOCH FROM (NEW.afternoon_in::time - v_a_start)) / 60)::INT;
        IF v_late_mins > 0 THEN
            v_deduction_mins := v_deduction_mins + v_late_mins;
        END IF;

        v_segment_credit := EXTRACT(EPOCH FROM (LEAST(NEW.afternoon_out::time, v_a_end) - v_a_start)) / 3600.0;
        v_segment_credit := v_segment_credit - (CEIL(v_late_mins / 30.0) * 0.5);
        
        v_regular_hours := v_regular_hours + GREATEST(0, v_segment_credit);
    END IF;

    -- 5. OVERTIME SEGMENT (Weekdays and Weekends)
    IF NEW.overtime_in IS NOT NULL AND NEW.overtime_out IS NOT NULL THEN
        v_overtime_hours := EXTRACT(EPOCH FROM (NEW.overtime_out::time - NEW.overtime_in::time)) / 3600.0;
    END IF;

    -- 6. FINALIZE RECORD
    NEW.regular_hours := v_regular_hours;
    NEW.overtime_hours := v_overtime_hours;
    NEW.total_hours := v_regular_hours + v_overtime_hours;
    NEW.deduction_minutes := v_deduction_mins;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- RE-APPLY THE TRIGGER
DROP TRIGGER IF EXISTS calculate_attendance_hours_trigger ON attendance;
CREATE TRIGGER calculate_attendance_hours_trigger
BEFORE INSERT OR UPDATE ON attendance
FOR EACH ROW EXECUTE FUNCTION calculate_attendance_hours();

-- RETROACTIVE UPDATE: Apply the new logic to all existing records
UPDATE attendance SET updated_at = CURRENT_TIMESTAMP;
