CREATE OR REPLACE FUNCTION public.calculate_risk_score(p_student_id integer)
 RETURNS TABLE(student_id integer, risk_score numeric, risk_level character varying, risk_factors jsonb, recommendations text[])
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_attendance_rate NUMERIC;
    v_avg_score NUMERIC;
    v_hours_completion NUMERIC;
    v_recent_attendance NUMERIC;
    v_score NUMERIC := 0;
    v_level VARCHAR(20);
    v_factors JSONB := '[]'::JSONB;
    v_recommendations TEXT[] := ARRAY[]::TEXT[];
BEGIN
    -- Calculate attendance rate (last 30 days) - Only approved attendance
    SELECT 
        COUNT(DISTINCT date)::NUMERIC / NULLIF(
            GREATEST((CURRENT_DATE - o.start_date), 1), 0
        ) * 100
    INTO v_recent_attendance
    FROM attendance a
    JOIN ojt_records o ON a.student_id = o.student_id
    WHERE a.student_id = p_student_id 
        AND a.date >= CURRENT_DATE - INTERVAL '30 days'
        AND a.status = 'Approved'  -- CRITICAL: Only approved attendance
        AND o.status = 'Ongoing'
    GROUP BY o.start_date;
    
    -- Get average evaluation score
    SELECT COALESCE(AVG(total_score), 0)
    INTO v_avg_score
    FROM evaluations
    WHERE student_id = p_student_id;
    
    -- Get hours completion percentage
    SELECT completion_percentage
    INTO v_hours_completion
    FROM get_student_progress(p_student_id);
    
    -- Calculate risk score (0-100, higher = more risk)
    IF v_recent_attendance < 70 THEN
        v_score := v_score + 30;
        v_factors := v_factors || jsonb_build_object('factor', 'Low Attendance', 'value', v_recent_attendance);
        v_recommendations := v_recommendations || 'Improve attendance consistency';
    END IF;
    
    IF v_avg_score < 75 THEN
        v_score := v_score + 25;
        v_factors := v_factors || jsonb_build_object('factor', 'Low Evaluation Score', 'value', v_avg_score);
        v_recommendations := v_recommendations || 'Focus on improving performance metrics';
    END IF;
    
    IF v_hours_completion < 50 AND (SELECT EXTRACT(EPOCH FROM (CURRENT_DATE - start_date)) / 86400 FROM ojt_records WHERE student_id = p_student_id AND status = 'Ongoing' LIMIT 1) > 60 THEN
        v_score := v_score + 25;
        v_factors := v_factors || jsonb_build_object('factor', 'Slow Progress', 'value', v_hours_completion);
        v_recommendations := v_recommendations || 'Increase weekly hours to meet requirements';
    END IF;
    
    -- Determine risk level
    IF v_score >= 60 THEN
        v_level := 'High';
    ELSIF v_score >= 40 THEN
        v_level := 'Medium';
    ELSIF v_score >= 20 THEN
        v_level := 'Low';
    ELSE
        v_level := 'Minimal';
    END IF;
    
    RETURN QUERY SELECT 
        p_student_id,
        v_score,
        v_level,
        v_factors,
        v_recommendations;
END;
$function$
