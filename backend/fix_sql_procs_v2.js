const { query } = require('./config/db');

async function fixProcs() {
  try {
    console.log('Dropping old procedures...');
    await query('DROP FUNCTION IF EXISTS generate_batch_predictions() CASCADE');
    await query('DROP FUNCTION IF EXISTS generate_performance_prediction(integer) CASCADE');
    await query('DROP FUNCTION IF EXISTS calculate_risk_score(integer) CASCADE');
    
    console.log('Creating calculate_risk_score...');
    await query(`
CREATE OR REPLACE FUNCTION public.calculate_risk_score(p_student_id integer)
 RETURNS TABLE(res_student_id integer, res_risk_score numeric, res_risk_level character varying, res_risk_factors jsonb, res_recommendations text[])
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
    -- Calculate attendance rate (last 30 days)
    SELECT 
        COUNT(DISTINCT a.date)::NUMERIC / NULLIF(
            GREATEST((CURRENT_DATE - o.start_date), 1), 0
        ) * 100
    INTO v_recent_attendance
    FROM attendance a
    JOIN ojt_records o ON a.student_id = o.student_id
    WHERE a.student_id = p_student_id 
        AND a.date >= CURRENT_DATE - INTERVAL '30 days'
        AND a.status = 'Approved'
        AND o.status = 'Ongoing'
    GROUP BY o.start_date;
    
    -- Get average evaluation score
    SELECT COALESCE(AVG(total_score), 0)
    INTO v_avg_score
    FROM evaluations
    WHERE student_id = p_student_id;
    
    -- Get hours completion percentage
    BEGIN
        SELECT completion_percentage
        INTO v_hours_completion
        FROM get_student_progress(p_student_id);
    EXCEPTION WHEN OTHERS THEN
        v_hours_completion := 0;
    END;
    
    -- Risk scoring logic
    IF COALESCE(v_recent_attendance, 0) < 70 THEN
        v_score := v_score + 30;
        v_factors := v_factors || jsonb_build_object('factor', 'Low Attendance', 'value', ROUND(COALESCE(v_recent_attendance, 0), 2));
        v_recommendations := v_recommendations || 'Improve attendance consistency';
    END IF;
    
    IF COALESCE(v_avg_score, 0) < 75 THEN
        v_score := v_score + 25;
        v_factors := v_factors || jsonb_build_object('factor', 'Low Evaluation Score', 'value', ROUND(COALESCE(v_avg_score, 0), 2));
        v_recommendations := v_recommendations || 'Focus on improving performance metrics';
    END IF;
    
    -- Slow progress check
    DECLARE
        v_days_since_start INT;
    BEGIN
        SELECT EXTRACT(DAY FROM (CURRENT_DATE - start_date))::INT
        INTO v_days_since_start
        FROM ojt_records 
        WHERE student_id = p_student_id AND status = 'Ongoing' 
        LIMIT 1;
        
        IF v_days_since_start > 60 AND COALESCE(v_hours_completion, 0) < 50 THEN
            v_score := v_score + 25;
            v_factors := v_factors || jsonb_build_object('factor', 'Slow Progress', 'value', ROUND(COALESCE(v_hours_completion, 0), 2));
            v_recommendations := v_recommendations || 'Increase weekly hours to meet requirements';
        END IF;
    END;
    
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
    `);

    console.log('Creating generate_performance_prediction...');
    await query(`
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
    -- Attendance trend
    SELECT 
        (COUNT(CASE WHEN date >= CURRENT_DATE - INTERVAL '14 days' THEN 1 END)::NUMERIC / 14 * 100) -
        (COUNT(CASE WHEN date >= CURRENT_DATE - INTERVAL '28 days' AND date < CURRENT_DATE - INTERVAL '14 days' THEN 1 END)::NUMERIC / 14 * 100)
    INTO v_attendance_trend
    FROM attendance
    WHERE student_id = p_student_id AND status = 'Approved';
    
    -- Evaluation trend
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
    
    -- Current score
    SELECT COALESCE(AVG(total_score), 75)
    INTO v_current_score
    FROM evaluations
    WHERE student_id = p_student_id;
    
    v_predicted_score := v_current_score + (v_evaluation_trend * 0.3) + (v_attendance_trend * 0.1);
    v_predicted_score := GREATEST(0, LEAST(100, v_predicted_score));
    
    -- Confidence
    SELECT 
        CASE 
            WHEN COUNT(*) >= 3 THEN 0.85
            WHEN COUNT(*) >= 1 THEN 0.70
            ELSE 0.50
        END
    INTO v_confidence
    FROM evaluations
    WHERE student_id = p_student_id;
    
    -- Build JSON
    SELECT jsonb_build_object(
        'student_id', p_student_id,
        'predicted_performance', ROUND(COALESCE(v_predicted_score, 75), 2),
        'current_performance', ROUND(COALESCE(v_current_score, 75), 2),
        'attendance_trend', ROUND(COALESCE(v_attendance_trend, 0), 2),
        'evaluation_trend', ROUND(COALESCE(v_evaluation_trend, 0), 2),
        'confidence', ROUND(v_confidence, 2),
        'prediction_date', CURRENT_TIMESTAMP,
        'risk_assessment', (SELECT jsonb_build_object(
            'risk_score', r.res_risk_score,
            'risk_level', r.res_risk_level,
            'risk_factors', r.res_risk_factors
        ) FROM calculate_risk_score(p_student_id) r LIMIT 1)
    ) INTO v_prediction;
    
    RETURN v_prediction;
END;
$function$
    `);

    console.log('Creating generate_batch_predictions...');
    await query(`
CREATE OR REPLACE FUNCTION public.generate_batch_predictions()
 RETURNS TABLE(student_id integer, out_insight_id integer, prediction_result jsonb)
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_student RECORD;
    v_insight_id INT;
BEGIN
    FOR v_student IN 
        SELECT DISTINCT u.user_id
        FROM users u
        JOIN ojt_records o ON u.user_id = o.student_id
        WHERE u.role = 'Student' AND o.status = 'Ongoing'
    LOOP
        INSERT INTO ai_insights (
            student_id,
            model_name,
            insight_type,
            result,
            confidence,
            input_data
        )
        VALUES (
            v_student.user_id,
            'Performance Prediction Model',
            'performance_prediction',
            generate_performance_prediction(v_student.user_id),
            (generate_performance_prediction(v_student.user_id)->>'confidence')::NUMERIC,
            jsonb_build_object('generated_at', CURRENT_TIMESTAMP, 'batch_job', TRUE)
        )
        RETURNING insight_id INTO v_insight_id;
        
        student_id := v_student.user_id;
        out_insight_id := v_insight_id;
        prediction_result := generate_performance_prediction(v_student.user_id);
        RETURN NEXT;
    END LOOP;
END;
$function$
    `);

    console.log('✅ All procedures fixed successfully');
    process.exit(0);
  } catch (error) {
    console.error('❌ FAILED TO FIX PROCS:', error.message);
    process.exit(1);
  }
}

fixProcs();
