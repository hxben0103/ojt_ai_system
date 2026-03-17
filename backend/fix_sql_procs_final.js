const { query } = require('./config/db');

async function fixProcsFinal() {
  try {
    console.log('Dropping all related functions...');
    await query('DROP FUNCTION IF EXISTS generate_batch_predictions() CASCADE');
    await query('DROP FUNCTION IF EXISTS generate_performance_prediction(integer) CASCADE');
    await query('DROP FUNCTION IF EXISTS calculate_risk_score(integer) CASCADE');
    
    console.log('Creating calculate_risk_score (returns JSONB)...');
    await query(`
CREATE OR REPLACE FUNCTION public.calculate_risk_score(p_student_id integer)
 RETURNS jsonb
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
    -- Calculate attendance rate
    SELECT 
        COUNT(DISTINCT a.date)::NUMERIC / NULLIF(GREATEST((CURRENT_DATE - o.start_date), 1), 0) * 100
    INTO v_recent_attendance
    FROM attendance a
    JOIN ojt_records o ON a.student_id = o.student_id
    WHERE a.student_id = p_student_id AND a.status = 'Approved' AND o.status = 'Ongoing'
    AND a.date >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY o.start_date;
    
    -- Get average eval
    SELECT COALESCE(AVG(total_score), 0) INTO v_avg_score FROM evaluations WHERE student_id = p_student_id;
    
    -- Get progress
    BEGIN
        SELECT completion_percentage INTO v_hours_completion FROM get_student_progress(p_student_id);
    EXCEPTION WHEN OTHERS THEN v_hours_completion := 0;
    END;
    
    -- Logic
    IF COALESCE(v_recent_attendance,0) < 70 THEN
        v_score := v_score + 30;
        v_factors := v_factors || jsonb_build_object('factor', 'Low Attendance', 'value', ROUND(COALESCE(v_recent_attendance,0), 1));
        v_recommendations := v_recommendations || 'Improve attendance consistency';
    END IF;
    
    IF COALESCE(v_avg_score,0) < 75 THEN
        v_score := v_score + 25;
        v_factors := v_factors || jsonb_build_object('factor', 'Low Evaluation Score', 'value', ROUND(COALESCE(v_avg_score,0), 1));
        v_recommendations := v_recommendations || 'Focus on improving performance metrics';
    END IF;
    
    -- Return JSONB
    IF v_score >= 60 THEN v_level := 'High';
    ELSIF v_score >= 40 THEN v_level := 'Medium';
    ELSIF v_score >= 20 THEN v_level := 'Low';
    ELSE v_level := 'Minimal';
    END IF;
    
    RETURN jsonb_build_object(
        'risk_score', v_score,
        'risk_level', v_level,
        'risk_factors', v_factors,
        'recommendations', v_recommendations
    );
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
    v_risk JSONB;
BEGIN
    SELECT 
        (COUNT(CASE WHEN date >= CURRENT_DATE - INTERVAL '14 days' THEN 1 END)::NUMERIC / 14 * 100) -
        (COUNT(CASE WHEN date >= CURRENT_DATE - INTERVAL '28 days' AND date < CURRENT_DATE - INTERVAL '14 days' THEN 1 END)::NUMERIC / 14 * 100)
    INTO v_attendance_trend
    FROM attendance
    WHERE student_id = p_student_id AND status = 'Approved';
    
    SELECT 
        COALESCE(
            (SELECT AVG(total_score) FROM evaluations WHERE student_id = p_student_id AND date_evaluated >= CURRENT_DATE - INTERVAL '30 days') -
            (SELECT AVG(total_score) FROM evaluations WHERE student_id = p_student_id AND date_evaluated >= CURRENT_DATE - INTERVAL '60 days' AND date_evaluated < CURRENT_DATE - INTERVAL '30 days'),
            0
        )
    INTO v_evaluation_trend;
    
    SELECT COALESCE(AVG(total_score), 75) INTO v_current_score FROM evaluations WHERE student_id = p_student_id;
    
    v_predicted_score := v_current_score + (COALESCE(v_evaluation_trend,0) * 0.3) + (COALESCE(v_attendance_trend,0) * 0.1);
    v_predicted_score := GREATEST(0, LEAST(100, v_predicted_score));
    
    SELECT CASE WHEN COUNT(*) >= 3 THEN 0.85 WHEN COUNT(*) >= 1 THEN 0.70 ELSE 0.50 END
    INTO v_confidence FROM evaluations WHERE student_id = p_student_id;
    
    v_risk := calculate_risk_score(p_student_id);
    
    RETURN jsonb_build_object(
        'student_id', p_student_id,
        'predicted_performance', ROUND(COALESCE(v_predicted_score, 75), 1),
        'current_performance', ROUND(COALESCE(v_current_score, 75), 1),
        'attendance_trend', ROUND(COALESCE(v_attendance_trend, 0), 1),
        'evaluation_trend', ROUND(COALESCE(v_evaluation_trend, 0), 1),
        'confidence', ROUND(v_confidence, 2),
        'risk_assessment', v_risk
    );
END;
$function$
    `);

    console.log('Creating generate_batch_predictions...');
    await query(`
CREATE OR REPLACE FUNCTION public.generate_batch_predictions()
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_student RECORD;
    v_count INTEGER := 0;
    v_prediction JSONB;
BEGIN
    FOR v_student IN 
        SELECT DISTINCT u.user_id
        FROM users u
        JOIN ojt_records o ON u.user_id = o.student_id
        WHERE u.role = 'Student' AND o.status = 'Ongoing'
    LOOP
        v_prediction := generate_performance_prediction(v_student.user_id);
        
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
            v_prediction,
            (v_prediction->>'confidence')::NUMERIC,
            jsonb_build_object('generated_at', CURRENT_TIMESTAMP, 'batch_job', TRUE)
        );
        
        v_count := v_count + 1;
    END LOOP;
    RETURN v_count;
END;
$function$
    `);

    console.log('✅ Final fixes applied successfully');
    process.exit(0);
  } catch (error) {
    console.error('❌ FINAL FIX FAILED:', error.message);
    process.exit(1);
  }
}

fixProcsFinal();
