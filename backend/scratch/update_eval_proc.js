const { query } = require('../config/db');

const sql = `
CREATE OR REPLACE FUNCTION public.create_evaluation(
    p_student_id integer, 
    p_supervisor_id integer, 
    p_criteria jsonb, 
    p_total_score numeric, 
    p_feedback text DEFAULT NULL::text, 
    p_evaluation_period_start date DEFAULT NULL::date, 
    p_evaluation_period_end date DEFAULT NULL::date,
    p_evaluation_type character varying DEFAULT 'SE'::character varying
)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_eval_id INT;
BEGIN
    -- Validate score range
    IF p_total_score < 0 OR p_total_score > 100 THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'errors', ARRAY['Total score must be between 0 and 100'],
            'eval_id', NULL
        );
    END IF;
    
    -- Insert evaluation with type
    INSERT INTO evaluations (
        student_id, supervisor_id, criteria, total_score,
        feedback, evaluation_period_start, evaluation_period_end, 
        evaluation_type, status
    )
    VALUES (
        p_student_id, p_supervisor_id, p_criteria, p_total_score,
        p_feedback, p_evaluation_period_start, p_evaluation_period_end, 
        p_evaluation_type, 'Draft'
    )
    RETURNING eval_id INTO v_eval_id;
    
    RETURN jsonb_build_object(
        'success', TRUE,
        'eval_id', v_eval_id,
        'message', 'Evaluation created successfully'
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'errors', ARRAY[SQLERRM],
            'eval_id', NULL
        );
END;
$function$;
`;

async function run() {
    try {
        await query(sql);
        console.log('✅ create_evaluation updated successfully');
        process.exit(0);
    } catch (e) {
        console.error('❌ Error updating function:', e);
        process.exit(1);
    }
}

run();
