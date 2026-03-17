const { query } = require('./config/db');

async function fixProcsActuallyFinal() {
  try {
    console.log('Fixing calculate_risk_score...');
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
     -- 1. Recent Attendance Rate
     SELECT 
         COUNT(DISTINCT a.date)::NUMERIC / NULLIF(GREATEST((CURRENT_DATE - o.start_date), 1), 0) * 100
     INTO v_recent_attendance
     FROM attendance a
     JOIN ojt_records o ON a.student_id = o.student_id
     WHERE a.student_id = p_student_id AND a.status = 'Approved' AND o.status = 'Ongoing'
     AND a.date >= CURRENT_DATE - INTERVAL '30 days'
     GROUP BY o.start_date;
     
     -- 2. Average Eval
     SELECT COALESCE(AVG(total_score), 0) INTO v_avg_score FROM evaluations WHERE student_id = p_student_id;
     
     -- 3. Progress
     BEGIN
         SELECT completion_percentage INTO v_hours_completion FROM get_student_progress(p_student_id);
     EXCEPTION WHEN OTHERS THEN v_hours_completion := 0;
     END;
     
     -- Scoring Logic
     IF COALESCE(v_recent_attendance, 0) < 70 THEN
         v_score := v_score + 30;
         v_factors := v_factors || jsonb_build_object('factor', 'Low Attendance', 'value', ROUND(COALESCE(v_recent_attendance, 0), 1));
         v_recommendations := array_append(v_recommendations, 'Improve attendance consistency');
     END IF;
     
     IF COALESCE(v_avg_score, 0) < 75 THEN
         v_score := v_score + 25;
         v_factors := v_factors || jsonb_build_object('factor', 'Low Evaluation Score', 'value', ROUND(COALESCE(v_avg_score, 0), 1));
         v_recommendations := array_append(v_recommendations, 'Focus on improving performance metrics');
     END IF;
     
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
    
    console.log('✅ calculate_risk_score fixed with array_append');
    process.exit(0);
  } catch (error) {
    console.error('❌ FIX FAILED:', error.message);
    process.exit(1);
  }
}

fixProcsActuallyFinal();
