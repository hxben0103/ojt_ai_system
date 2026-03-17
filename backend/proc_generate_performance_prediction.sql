CREATE OR REPLACE FUNCTION public.generate_performance_prediction(p_student_id integer)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_prediction JSONB;
    v_attendance_trend NUMERIC;
    v_evaluation_trend NUMERIC;
    v_current_score NUMERIC;
    v_predicted_score NUMERIC;
    v_confidence NUMERIC;
BEGIN
    -- Calculate attendance trend (comparing last 2 weeks vs previous 2 weeks) - Only approved attendance
    SELECT 
        (COUNT(CASE WHEN date >= CURRENT_DATE - INTERVAL '14 days' THEN 1 END)::NUMERIC / 14 * 100) -
        (COUNT(CASE WHEN date >= CURRENT_DATE - INTERVAL '28 days' AND date < CURRENT_DATE - INTERVAL '14 days' THEN 1 END)::NUMERIC / 14 * 100)
    INTO v_attendance_trend
    FROM attendance
    WHERE student_id = p_student_id AND status = 'Approved';  -- CRITICAL: Only approved attendance
    
    -- Calculate evaluation trend
    SELECT 
        COALESCE(
            (SELECT AVG(total_score) FROM evaluations 
             WHERE student_id = p_student_id 
             AND date_evaluated >= CURRENT_DATE - INTERVAL '30 days') -
            (SELECT AVG(total_score) FROM evaluations 
             WHERE student_id = p_student_id 
             AND date_evaluated >= CURRENT_DATE - INTERVAL '60 days' 
             AND date_evaluated < CURRENT_DATE - INTERVAL '30 days'),
            0
        )
    INTO v_evaluation_trend;
    
    -- Get current average score
    SELECT COALESCE(AVG(total_score), 75)
    INTO v_current_score
    FROM evaluations
    WHERE student_id = p_student_id;
    
    -- Simple prediction: current score + trend adjustment
    v_predicted_score := v_current_score + (v_evaluation_trend * 0.3) + (v_attendance_trend * 0.1);
    v_predicted_score := GREATEST(0, LEAST(100, v_predicted_score));
    
    -- Calculate confidence based on data availability
    SELECT 
        CASE 
            WHEN COUNT(*) >= 3 THEN 0.85
            WHEN COUNT(*) >= 1 THEN 0.70
            ELSE 0.50
        END
    INTO v_confidence
    FROM evaluations
    WHERE student_id = p_student_id;
    
    -- Build prediction result
    v_prediction := jsonb_build_object(
        'student_id', p_student_id,
        'predicted_performance', ROUND(v_predicted_score, 2),
        'current_performance', ROUND(v_current_score, 2),
        'attendance_trend', ROUND(v_attendance_trend, 2),
        'evaluation_trend', ROUND(v_evaluation_trend, 2),
        'confidence', ROUND(v_confidence, 2),
        'prediction_date', CURRENT_TIMESTAMP,
        'risk_assessment', (SELECT jsonb_build_object(
            'risk_score', risk_score,
            'risk_level', risk_level,
            'risk_factors', risk_factors
        ) FROM calculate_risk_score(p_student_id))
    );
    
    RETURN v_prediction;
END;
$function$
