CREATE OR REPLACE FUNCTION public.generate_batch_predictions()
 RETURNS TABLE(student_id integer, prediction_id integer, prediction_result jsonb)
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_student RECORD;
    v_insight_id INT;
BEGIN
    -- Loop through all active students
    FOR v_student IN 
        SELECT DISTINCT u.user_id
        FROM users u
        JOIN ojt_records o ON u.user_id = o.student_id
        WHERE u.role = 'Student' AND o.status = 'Ongoing'
    LOOP
        -- Generate prediction
        INSERT INTO ai_insights (
            student_id,
            model_name,
            insight_type,
            result,
            confidence,
            input_data
        )
        SELECT 
            v_student.user_id,
            'Performance Prediction Model',
            'performance_prediction',
            generate_performance_prediction(v_student.user_id),
            (generate_performance_prediction(v_student.user_id)->>'confidence')::NUMERIC,
            jsonb_build_object(
                'generated_at', CURRENT_TIMESTAMP,
                'batch_job', TRUE
            )
        RETURNING insight_id INTO v_insight_id;
        
        -- Return result
        RETURN QUERY SELECT 
            v_student.user_id,
            v_insight_id,
            generate_performance_prediction(v_student.user_id);
    END LOOP;
END;
$function$
