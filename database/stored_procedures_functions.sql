-- =====================================================
-- PostgreSQL Stored Procedures and Functions
-- Intelligent AI-Powered OJT Monitoring System
-- =====================================================

-- =====================================================
-- 1. STUDENT PROGRESS & ANALYTICS FUNCTIONS
-- =====================================================

-- Function: Calculate Student Progress Percentage
CREATE OR REPLACE FUNCTION get_student_progress(p_student_id INT)
RETURNS TABLE (
    student_id INT,
    full_name VARCHAR(100),
    required_hours NUMERIC,
    completed_hours NUMERIC,
    completion_percentage NUMERIC,
    attendance_days INT,
    remaining_hours NUMERIC,
    estimated_completion_date DATE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.user_id,
        u.full_name,
        COALESCE(o.required_hours, u.required_hours, 300)::NUMERIC AS req_hours,
        COALESCE(SUM(a.total_hours), 0)::NUMERIC AS comp_hours,
        ROUND(
            (COALESCE(SUM(a.total_hours), 0)::NUMERIC / 
             NULLIF(COALESCE(o.required_hours, u.required_hours, 300), 0) * 100), 
            2
        ) AS completion_pct,
        COUNT(DISTINCT a.date)::INT AS att_days,
        GREATEST(
            (COALESCE(o.required_hours, u.required_hours, 300) - COALESCE(SUM(a.total_hours), 0))::NUMERIC,
            0
        ) AS rem_hours,
        CASE 
            WHEN AVG(a.total_hours) > 0 AND o.end_date IS NULL THEN
                CURRENT_DATE + INTERVAL '1 day' * 
                CEIL((COALESCE(o.required_hours, u.required_hours, 300) - COALESCE(SUM(a.total_hours), 0)) / AVG(a.total_hours))
            ELSE o.end_date
        END AS est_completion
    FROM users u
    LEFT JOIN ojt_records o ON u.user_id = o.student_id AND o.status = 'Ongoing'
    LEFT JOIN attendance a ON u.user_id = a.student_id
    WHERE u.user_id = p_student_id AND u.role = 'Student'
    GROUP BY u.user_id, u.full_name, o.required_hours, u.required_hours, o.end_date;
END;
$$ LANGUAGE plpgsql;

-- Function: Get Real-Time Student Analytics
CREATE OR REPLACE FUNCTION get_student_analytics(p_student_id INT)
RETURNS JSONB AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'student_info', (
            SELECT jsonb_build_object(
                'user_id', u.user_id,
                'full_name', u.full_name,
                'student_id', u.student_id,
                'course', u.course,
                'email', u.email
            )
            FROM users u
            WHERE u.user_id = p_student_id
        ),
        'ojt_info', (
            SELECT jsonb_build_object(
                'company_name', o.company_name,
                'start_date', o.start_date,
                'end_date', o.end_date,
                'status', o.status,
                'required_hours', o.required_hours
            )
            FROM ojt_records o
            WHERE o.student_id = p_student_id AND o.status = 'Ongoing'
            LIMIT 1
        ),
        'attendance_stats', (
            SELECT jsonb_build_object(
                'total_days', COUNT(DISTINCT a.date),
                'total_hours', COALESCE(SUM(a.total_hours), 0),
                'avg_hours_per_day', COALESCE(AVG(a.total_hours), 0),
                'verified_days', COUNT(CASE WHEN a.verified THEN 1 END),
                'last_attendance', MAX(a.date)
            )
            FROM attendance a
            WHERE a.student_id = p_student_id
        ),
        'evaluation_stats', (
            SELECT jsonb_build_object(
                'total_evaluations', COUNT(*),
                'avg_score', COALESCE(AVG(e.total_score), 0),
                'latest_score', (
                    SELECT total_score 
                    FROM evaluations 
                    WHERE student_id = p_student_id 
                    ORDER BY date_evaluated DESC 
                    LIMIT 1
                ),
                'latest_evaluation_date', MAX(e.date_evaluated)
            )
            FROM evaluations e
            WHERE e.student_id = p_student_id
        ),
        'ai_insights', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'insight_type', ai.insight_type,
                    'prediction', ai.result->>'predicted_performance',
                    'risk_level', ai.result->>'risk_level',
                    'confidence', ai.confidence,
                    'created_at', ai.created_at
                )
            )
            FROM ai_insights ai
            WHERE ai.student_id = p_student_id
            ORDER BY ai.created_at DESC
            LIMIT 5
        ),
        'progress', (
            SELECT * FROM get_student_progress(p_student_id)
        )
    ) INTO result;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 2. PERFORMANCE PREDICTION & RISK ASSESSMENT
-- =====================================================

-- Function: Calculate Performance Risk Score
CREATE OR REPLACE FUNCTION calculate_risk_score(p_student_id INT)
RETURNS TABLE (
    student_id INT,
    risk_score NUMERIC,
    risk_level VARCHAR(20),
    risk_factors JSONB,
    recommendations TEXT[]
) AS $$
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
        COUNT(DISTINCT date)::NUMERIC / NULLIF(
            GREATEST((CURRENT_DATE - o.start_date), 1), 0
        ) * 100
    INTO v_recent_attendance
    FROM attendance a
    JOIN ojt_records o ON a.student_id = o.student_id
    WHERE a.student_id = p_student_id 
        AND a.date >= CURRENT_DATE - INTERVAL '30 days'
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
$$ LANGUAGE plpgsql;

-- Function: Generate Performance Prediction
CREATE OR REPLACE FUNCTION generate_performance_prediction(p_student_id INT)
RETURNS JSONB AS $$
DECLARE
    v_prediction JSONB;
    v_attendance_trend NUMERIC;
    v_evaluation_trend NUMERIC;
    v_current_score NUMERIC;
    v_predicted_score NUMERIC;
    v_confidence NUMERIC;
BEGIN
    -- Calculate attendance trend (comparing last 2 weeks vs previous 2 weeks)
    SELECT 
        (COUNT(CASE WHEN date >= CURRENT_DATE - INTERVAL '14 days' THEN 1 END)::NUMERIC / 14 * 100) -
        (COUNT(CASE WHEN date >= CURRENT_DATE - INTERVAL '28 days' AND date < CURRENT_DATE - INTERVAL '14 days' THEN 1 END)::NUMERIC / 14 * 100)
    INTO v_attendance_trend
    FROM attendance
    WHERE student_id = p_student_id;
    
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
$$ LANGUAGE plpgsql;

-- =====================================================
-- 3. ATTENDANCE VALIDATION & CALCULATIONS
-- =====================================================

-- Function: Validate Attendance Entry
CREATE OR REPLACE FUNCTION validate_attendance(
    p_student_id INT,
    p_date DATE,
    p_time_in TIME,
    p_time_out TIME DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
    v_is_valid BOOLEAN := TRUE;
    v_errors TEXT[] := ARRAY[]::TEXT[];
    v_existing_count INT;
    v_ojt_status VARCHAR(20);
BEGIN
    -- Check if student has active OJT
    SELECT status INTO v_ojt_status
    FROM ojt_records
    WHERE student_id = p_student_id AND status = 'Ongoing'
    LIMIT 1;
    
    IF v_ojt_status IS NULL THEN
        v_is_valid := FALSE;
        v_errors := v_errors || 'Student does not have an active OJT record';
    END IF;
    
    -- Check if date is within OJT period
    IF NOT EXISTS (
        SELECT 1 FROM ojt_records
        WHERE student_id = p_student_id
        AND status = 'Ongoing'
        AND p_date >= COALESCE(start_date, CURRENT_DATE - INTERVAL '1 year')
        AND p_date <= COALESCE(end_date, CURRENT_DATE + INTERVAL '1 year')
    ) THEN
        v_is_valid := FALSE;
        v_errors := v_errors || 'Date is outside OJT period';
    END IF;
    
    -- Check for duplicate entry
    SELECT COUNT(*) INTO v_existing_count
    FROM attendance
    WHERE student_id = p_student_id AND date = p_date;
    
    IF v_existing_count > 0 THEN
        v_is_valid := FALSE;
        v_errors := v_errors || 'Attendance already recorded for this date';
    END IF;
    
    -- Validate time range
    IF p_time_out IS NOT NULL AND p_time_in >= p_time_out THEN
        v_is_valid := FALSE;
        v_errors := v_errors || 'Time out must be after time in';
    END IF;
    
    -- Check if date is in the future
    IF p_date > CURRENT_DATE THEN
        v_is_valid := FALSE;
        v_errors := v_errors || 'Cannot record attendance for future dates';
    END IF;
    
    v_result := jsonb_build_object(
        'is_valid', v_is_valid,
        'errors', v_errors,
        'warnings', ARRAY[]::TEXT[]
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- Function: Get Attendance Statistics for Period
CREATE OR REPLACE FUNCTION get_attendance_statistics(
    p_student_id INT,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
    v_start DATE := COALESCE(p_start_date, CURRENT_DATE - INTERVAL '30 days');
    v_end DATE := COALESCE(p_end_date, CURRENT_DATE);
BEGIN
    SELECT jsonb_build_object(
        'period', jsonb_build_object(
            'start_date', v_start,
            'end_date', v_end
        ),
        'summary', jsonb_build_object(
            'total_days', COUNT(DISTINCT a.date),
            'total_hours', COALESCE(SUM(a.total_hours), 0),
            'avg_hours_per_day', COALESCE(AVG(a.total_hours), 0),
            'max_hours_day', COALESCE(MAX(a.total_hours), 0),
            'min_hours_day', COALESCE(MIN(a.total_hours), 0),
            'verified_days', COUNT(CASE WHEN a.verified THEN 1 END),
            'unverified_days', COUNT(CASE WHEN NOT a.verified THEN 1 END)
        ),
        'daily_breakdown', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'date', a.date,
                    'time_in', a.time_in,
                    'time_out', a.time_out,
                    'total_hours', a.total_hours,
                    'verified', a.verified
                )
                ORDER BY a.date DESC
            )
            FROM attendance a
            WHERE a.student_id = p_student_id
            AND a.date BETWEEN v_start AND v_end
        ),
        'weekly_summary', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'week_start', week_start,
                    'week_end', week_end,
                    'total_hours', week_hours,
                    'days_present', days_count
                )
            )
            FROM (
                SELECT 
                    DATE_TRUNC('week', a.date)::DATE AS week_start,
                    (DATE_TRUNC('week', a.date) + INTERVAL '6 days')::DATE AS week_end,
                    SUM(a.total_hours) AS week_hours,
                    COUNT(DISTINCT a.date) AS days_count
                FROM attendance a
                WHERE a.student_id = p_student_id
                AND a.date BETWEEN v_start AND v_end
                GROUP BY DATE_TRUNC('week', a.date)
                ORDER BY week_start DESC
            ) weekly_data
        )
    ) INTO v_result
    FROM attendance a
    WHERE a.student_id = p_student_id
    AND a.date BETWEEN v_start AND v_end;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 4. REPORT GENERATION FUNCTIONS
-- =====================================================

-- Stored Procedure: Generate Student Progress Report
CREATE OR REPLACE FUNCTION generate_student_progress_report(
    p_student_id INT,
    p_generated_by INT,
    p_report_period_start DATE DEFAULT NULL,
    p_report_period_end DATE DEFAULT NULL
)
RETURNS INT AS $$
DECLARE
    v_report_id INT;
    v_start_date DATE := COALESCE(p_report_period_start, (SELECT start_date FROM ojt_records WHERE student_id = p_student_id AND status = 'Ongoing' LIMIT 1));
    v_end_date DATE := COALESCE(p_report_period_end, CURRENT_DATE);
    v_report_content JSONB;
BEGIN
    -- Build comprehensive report content
    v_report_content := jsonb_build_object(
        'student_info', (SELECT jsonb_build_object(
            'user_id', user_id,
            'full_name', full_name,
            'student_id', student_id,
            'course', course,
            'email', email
        ) FROM users WHERE user_id = p_student_id),
        'ojt_info', (SELECT jsonb_build_object(
            'company_name', company_name,
            'start_date', start_date,
            'end_date', end_date,
            'status', status,
            'required_hours', required_hours
        ) FROM ojt_records WHERE student_id = p_student_id AND status = 'Ongoing' LIMIT 1),
        'progress', (SELECT * FROM get_student_progress(p_student_id)),
        'attendance_stats', get_attendance_statistics(p_student_id, v_start_date, v_end_date),
        'evaluations', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'eval_id', eval_id,
                    'supervisor_id', supervisor_id,
                    'total_score', total_score,
                    'date_evaluated', date_evaluated,
                    'feedback', feedback
                )
                ORDER BY date_evaluated DESC
            )
            FROM evaluations
            WHERE student_id = p_student_id
            AND date_evaluated BETWEEN v_start_date AND v_end_date
        ),
        'ai_insights', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'insight_type', insight_type,
                    'result', result,
                    'confidence', confidence,
                    'created_at', created_at
                )
                ORDER BY created_at DESC
            )
            FROM ai_insights
            WHERE student_id = p_student_id
            AND created_at::DATE BETWEEN v_start_date AND v_end_date
        ),
        'risk_assessment', (SELECT jsonb_build_object(
            'risk_score', risk_score,
            'risk_level', risk_level,
            'risk_factors', risk_factors,
            'recommendations', recommendations
        ) FROM calculate_risk_score(p_student_id)),
        'generated_at', CURRENT_TIMESTAMP
    );
    
    -- Insert report
    INSERT INTO system_reports (
        report_type,
        generated_by,
        content,
        report_period_start,
        report_period_end,
        status
    ) VALUES (
        'Student Progress Report',
        p_generated_by,
        v_report_content,
        v_start_date,
        v_end_date,
        'Generated'
    ) RETURNING report_id INTO v_report_id;
    
    RETURN v_report_id;
END;
$$ LANGUAGE plpgsql;

-- Stored Procedure: Generate Batch Performance Predictions
CREATE OR REPLACE FUNCTION generate_batch_predictions()
RETURNS TABLE (
    student_id INT,
    prediction_id INT,
    prediction_result JSONB
) AS $$
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
$$ LANGUAGE plpgsql;

-- =====================================================
-- 5. DATA VALIDATION & BUSINESS LOGIC
-- =====================================================

-- Function: Validate OJT Record
CREATE OR REPLACE FUNCTION validate_ojt_record(
    p_student_id INT,
    p_start_date DATE,
    p_end_date DATE
)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
    v_is_valid BOOLEAN := TRUE;
    v_errors TEXT[] := ARRAY[]::TEXT[];
    v_existing_count INT;
BEGIN
    -- Check if student exists and is a student role
    IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = p_student_id AND role = 'Student') THEN
        v_is_valid := FALSE;
        v_errors := v_errors || 'Invalid student ID or user is not a student';
    END IF;
    
    -- Check for overlapping OJT records
    SELECT COUNT(*) INTO v_existing_count
    FROM ojt_records
    WHERE student_id = p_student_id
    AND status = 'Ongoing'
    AND (
        (p_start_date BETWEEN start_date AND COALESCE(end_date, CURRENT_DATE + INTERVAL '1 year'))
        OR (p_end_date BETWEEN start_date AND COALESCE(end_date, CURRENT_DATE + INTERVAL '1 year'))
        OR (start_date BETWEEN p_start_date AND p_end_date)
    );
    
    IF v_existing_count > 0 THEN
        v_is_valid := FALSE;
        v_errors := v_errors || 'Student already has an active OJT record with overlapping dates';
    END IF;
    
    -- Validate date range
    IF p_start_date >= p_end_date THEN
        v_is_valid := FALSE;
        v_errors := v_errors || 'End date must be after start date';
    END IF;
    
    -- Check if start date is too far in the past
    IF p_start_date < CURRENT_DATE - INTERVAL '2 years' THEN
        v_is_valid := FALSE;
        v_errors := v_errors || 'Start date cannot be more than 2 years in the past';
    END IF;
    
    v_result := jsonb_build_object(
        'is_valid', v_is_valid,
        'errors', v_errors
    );
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- Function: Auto-Complete OJT Record
CREATE OR REPLACE FUNCTION auto_complete_ojt_record(p_record_id INT)
RETURNS BOOLEAN AS $$
DECLARE
    v_student_id INT;
    v_required_hours NUMERIC;
    v_completed_hours NUMERIC;
    v_completion_pct NUMERIC;
BEGIN
    -- Get OJT record details
    SELECT 
        student_id,
        required_hours,
        (SELECT completion_percentage FROM get_student_progress(student_id))
    INTO v_student_id, v_required_hours, v_completion_pct
    FROM ojt_records
    WHERE record_id = p_record_id;
    
    -- Check if completion criteria met
    IF v_completion_pct >= 100 THEN
        -- Update status to Completed
        UPDATE ojt_records
        SET 
            status = 'Completed',
            end_date = COALESCE(end_date, CURRENT_DATE),
            updated_at = CURRENT_TIMESTAMP
        WHERE record_id = p_record_id;
        
        RETURN TRUE;
    END IF;
    
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 6. ANALYTICS & AGGREGATION FUNCTIONS
-- =====================================================

-- Function: Get System-Wide Statistics
CREATE OR REPLACE FUNCTION get_system_statistics()
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'students', jsonb_build_object(
            'total_students', (SELECT COUNT(*) FROM users WHERE role = 'Student'),
            'active_ojt', (SELECT COUNT(*) FROM ojt_records WHERE status = 'Ongoing'),
            'completed_ojt', (SELECT COUNT(*) FROM ojt_records WHERE status = 'Completed')
        ),
        'attendance', jsonb_build_object(
            'total_records', (SELECT COUNT(*) FROM attendance),
            'verified_records', (SELECT COUNT(*) FROM attendance WHERE verified = TRUE),
            'total_hours_logged', (SELECT COALESCE(SUM(total_hours), 0) FROM attendance)
        ),
        'evaluations', jsonb_build_object(
            'total_evaluations', (SELECT COUNT(*) FROM evaluations),
            'avg_score', (SELECT COALESCE(AVG(total_score), 0) FROM evaluations),
            'pending_approvals', (SELECT COUNT(*) FROM evaluations WHERE status = 'Draft')
        ),
        'ai_insights', jsonb_build_object(
            'total_insights', (SELECT COUNT(*) FROM ai_insights),
            'avg_confidence', (SELECT COALESCE(AVG(confidence), 0) FROM ai_insights),
            'latest_insight_date', (SELECT MAX(created_at) FROM ai_insights)
        ),
        'chatbot', jsonb_build_object(
            'total_interactions', (SELECT COUNT(*) FROM chatbot_logs),
            'unique_users', (SELECT COUNT(DISTINCT user_id) FROM chatbot_logs),
            'last_interaction', (SELECT MAX(timestamp) FROM chatbot_logs)
        ),
        'generated_at', CURRENT_TIMESTAMP
    ) INTO v_result;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- Function: Get At-Risk Students
CREATE OR REPLACE FUNCTION get_at_risk_students(p_risk_level VARCHAR DEFAULT 'Medium')
RETURNS TABLE (
    student_id INT,
    full_name VARCHAR(100),
    student_id_number VARCHAR(50),
    course VARCHAR(100),
    company_name VARCHAR(100),
    risk_score NUMERIC,
    risk_level VARCHAR(20),
    risk_factors JSONB,
    recommendations TEXT[]
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.user_id,
        u.full_name,
        u.student_id,
        u.course,
        o.company_name,
        rs.risk_score,
        rs.risk_level,
        rs.risk_factors,
        rs.recommendations
    FROM users u
    JOIN ojt_records o ON u.user_id = o.student_id AND o.status = 'Ongoing'
    CROSS JOIN LATERAL calculate_risk_score(u.user_id) rs
    WHERE u.role = 'Student'
    AND (
        CASE p_risk_level
            WHEN 'High' THEN rs.risk_level = 'High'
            WHEN 'Medium' THEN rs.risk_level IN ('High', 'Medium')
            ELSE TRUE
        END
    )
    ORDER BY rs.risk_score DESC;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 7. TRIGGER FUNCTIONS FOR AUTOMATION
-- =====================================================

-- Function: Auto-generate prediction on new evaluation
CREATE OR REPLACE FUNCTION trigger_performance_prediction()
RETURNS TRIGGER AS $$
BEGIN
    -- Generate and store prediction when new evaluation is added
    INSERT INTO ai_insights (
        student_id,
        model_name,
        insight_type,
        result,
        confidence,
        input_data
    )
    VALUES (
        NEW.student_id,
        'Auto Prediction Model',
        'performance_prediction',
        generate_performance_prediction(NEW.student_id),
        (generate_performance_prediction(NEW.student_id)->>'confidence')::NUMERIC,
        jsonb_build_object(
            'triggered_by', 'evaluation_insert',
            'eval_id', NEW.eval_id,
            'triggered_at', CURRENT_TIMESTAMP
        )
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for automatic prediction generation
DROP TRIGGER IF EXISTS auto_predict_on_evaluation ON evaluations;
CREATE TRIGGER auto_predict_on_evaluation
AFTER INSERT ON evaluations
FOR EACH ROW
WHEN (NEW.status = 'Approved')
EXECUTE FUNCTION trigger_performance_prediction();

-- =====================================================
-- 8. CRUD OPERATIONS FOR REST API
-- =====================================================

-- ========== USERS CRUD ==========

-- Create User (with validation)
CREATE OR REPLACE FUNCTION create_user(
    p_full_name VARCHAR(100),
    p_email VARCHAR(100),
    p_password_hash TEXT,
    p_role VARCHAR(20),
    p_student_id VARCHAR(50) DEFAULT NULL,
    p_course VARCHAR(100) DEFAULT NULL,
    p_contact_number VARCHAR(20) DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_user_id INT;
    v_result JSONB;
    v_errors TEXT[] := ARRAY[]::TEXT[];
BEGIN
    -- Validate email format
    IF p_email !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
        v_errors := v_errors || 'Invalid email format';
    END IF;
    
    -- Check if email already exists
    IF EXISTS (SELECT 1 FROM users WHERE email = p_email) THEN
        v_errors := v_errors || 'Email already exists';
    END IF;
    
    -- Validate role
    IF p_role NOT IN ('Admin', 'Coordinator', 'Supervisor', 'Student') THEN
        v_errors := v_errors || 'Invalid role';
    END IF;
    
    -- If errors, return them
    IF array_length(v_errors, 1) > 0 THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'errors', v_errors,
            'user_id', NULL
        );
    END IF;
    
    -- Insert user
    INSERT INTO users (
        full_name, email, password_hash, role, status,
        student_id, course, contact_number
    )
    VALUES (
        p_full_name, p_email, p_password_hash, p_role, 'Active',
        p_student_id, p_course, p_contact_number
    )
    RETURNING user_id INTO v_user_id;
    
    -- Return success with user data
    SELECT jsonb_build_object(
        'success', TRUE,
        'user_id', v_user_id,
        'user', jsonb_build_object(
            'user_id', v_user_id,
            'full_name', p_full_name,
            'email', p_email,
            'role', p_role,
            'status', 'Active'
        )
    ) INTO v_result;
    
    RETURN v_result;
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'errors', ARRAY[SQLERRM],
            'user_id', NULL
        );
END;
$$ LANGUAGE plpgsql;

-- Get User by ID
CREATE OR REPLACE FUNCTION get_user(p_user_id INT)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'user_id', u.user_id,
        'full_name', u.full_name,
        'email', u.email,
        'role', u.role,
        'status', u.status,
        'student_id', u.student_id,
        'course', u.course,
        'contact_number', u.contact_number,
        'date_created', u.date_created
    ) INTO v_result
    FROM users u
    WHERE u.user_id = p_user_id;
    
    RETURN COALESCE(v_result, jsonb_build_object('error', 'User not found'));
END;
$$ LANGUAGE plpgsql;

-- Update User
CREATE OR REPLACE FUNCTION update_user(
    p_user_id INT,
    p_full_name VARCHAR(100) DEFAULT NULL,
    p_email VARCHAR(100) DEFAULT NULL,
    p_role VARCHAR(20) DEFAULT NULL,
    p_status VARCHAR(20) DEFAULT NULL,
    p_student_id VARCHAR(50) DEFAULT NULL,
    p_course VARCHAR(100) DEFAULT NULL,
    p_contact_number VARCHAR(20) DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
    v_errors TEXT[] := ARRAY[]::TEXT[];
BEGIN
    -- Check if user exists
    IF NOT EXISTS (SELECT 1 FROM users WHERE user_id = p_user_id) THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'errors', ARRAY['User not found']
        );
    END IF;
    
    -- Validate email if provided
    IF p_email IS NOT NULL AND p_email !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
        v_errors := v_errors || 'Invalid email format';
    END IF;
    
    -- Check email uniqueness if changed
    IF p_email IS NOT NULL AND EXISTS (
        SELECT 1 FROM users WHERE email = p_email AND user_id != p_user_id
    ) THEN
        v_errors := v_errors || 'Email already exists';
    END IF;
    
    IF array_length(v_errors, 1) > 0 THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'errors', v_errors
        );
    END IF;
    
    -- Update user
    UPDATE users SET
        full_name = COALESCE(p_full_name, full_name),
        email = COALESCE(p_email, email),
        role = COALESCE(p_role, role),
        status = COALESCE(p_status, status),
        student_id = COALESCE(p_student_id, student_id),
        course = COALESCE(p_course, course),
        contact_number = COALESCE(p_contact_number, contact_number)
    WHERE user_id = p_user_id
    RETURNING jsonb_build_object(
        'success', TRUE,
        'user_id', user_id,
        'full_name', full_name,
        'email', email,
        'role', role,
        'status', status
    ) INTO v_result;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- Delete User (soft delete by setting status)
CREATE OR REPLACE FUNCTION delete_user(p_user_id INT)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    -- Soft delete by setting status to 'Inactive'
    UPDATE users
    SET status = 'Inactive'
    WHERE user_id = p_user_id
    RETURNING jsonb_build_object(
        'success', TRUE,
        'message', 'User deactivated successfully',
        'user_id', user_id
    ) INTO v_result;
    
    IF v_result IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'User not found'
        );
    END IF;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- ========== OJT RECORDS CRUD ==========

-- Create OJT Record
CREATE OR REPLACE FUNCTION create_ojt_record(
    p_student_id INT,
    p_company_name VARCHAR(100),
    p_coordinator_id INT,
    p_supervisor_id INT,
    p_start_date DATE,
    p_end_date DATE DEFAULT NULL,
    p_required_hours INT DEFAULT 300,
    p_company_address TEXT DEFAULT NULL,
    p_company_contact VARCHAR(50) DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_record_id INT;
    v_validation JSONB;
    v_result JSONB;
BEGIN
    -- Validate OJT record
    v_validation := validate_ojt_record(p_student_id, p_start_date, COALESCE(p_end_date, p_start_date + INTERVAL '6 months'));
    
    IF NOT (v_validation->>'is_valid')::BOOLEAN THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'errors', v_validation->'errors',
            'record_id', NULL
        );
    END IF;
    
    -- Insert OJT record
    INSERT INTO ojt_records (
        student_id, company_name, coordinator_id, supervisor_id,
        start_date, end_date, required_hours, status,
        company_address, company_contact
    )
    VALUES (
        p_student_id, p_company_name, p_coordinator_id, p_supervisor_id,
        p_start_date, p_end_date, p_required_hours, 'Ongoing',
        p_company_address, p_company_contact
    )
    RETURNING record_id INTO v_record_id;
    
    RETURN jsonb_build_object(
        'success', TRUE,
        'record_id', v_record_id,
        'message', 'OJT record created successfully'
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'errors', ARRAY[SQLERRM],
            'record_id', NULL
        );
END;
$$ LANGUAGE plpgsql;

-- Get OJT Record by ID
CREATE OR REPLACE FUNCTION get_ojt_record(p_record_id INT)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'record_id', o.record_id,
        'student_id', o.student_id,
        'student_name', s.full_name,
        'company_name', o.company_name,
        'coordinator_id', o.coordinator_id,
        'coordinator_name', c.full_name,
        'supervisor_id', o.supervisor_id,
        'supervisor_name', sup.full_name,
        'start_date', o.start_date,
        'end_date', o.end_date,
        'status', o.status,
        'required_hours', o.required_hours,
        'company_address', o.company_address,
        'company_contact', o.company_contact,
        'created_at', o.created_at
    ) INTO v_result
    FROM ojt_records o
    JOIN users s ON o.student_id = s.user_id
    JOIN users c ON o.coordinator_id = c.user_id
    JOIN users sup ON o.supervisor_id = sup.user_id
    WHERE o.record_id = p_record_id;
    
    RETURN COALESCE(v_result, jsonb_build_object('error', 'OJT record not found'));
END;
$$ LANGUAGE plpgsql;

-- Update OJT Record
CREATE OR REPLACE FUNCTION update_ojt_record(
    p_record_id INT,
    p_company_name VARCHAR(100) DEFAULT NULL,
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL,
    p_status VARCHAR(20) DEFAULT NULL,
    p_required_hours INT DEFAULT NULL,
    p_company_address TEXT DEFAULT NULL,
    p_company_contact VARCHAR(50) DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
    v_student_id INT;
BEGIN
    -- Get student_id for validation
    SELECT student_id INTO v_student_id
    FROM ojt_records
    WHERE record_id = p_record_id;
    
    IF v_student_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'OJT record not found'
        );
    END IF;
    
    -- Update OJT record
    UPDATE ojt_records SET
        company_name = COALESCE(p_company_name, company_name),
        start_date = COALESCE(p_start_date, start_date),
        end_date = COALESCE(p_end_date, end_date),
        status = COALESCE(p_status, status),
        required_hours = COALESCE(p_required_hours, required_hours),
        company_address = COALESCE(p_company_address, company_address),
        company_contact = COALESCE(p_company_contact, company_contact),
        updated_at = CURRENT_TIMESTAMP
    WHERE record_id = p_record_id
    RETURNING jsonb_build_object(
        'success', TRUE,
        'record_id', record_id,
        'status', status
    ) INTO v_result;
    
    -- Auto-complete if criteria met
    IF p_status = 'Ongoing' OR p_status IS NULL THEN
        PERFORM auto_complete_ojt_record(p_record_id);
    END IF;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- Delete OJT Record
CREATE OR REPLACE FUNCTION delete_ojt_record(p_record_id INT)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    DELETE FROM ojt_records
    WHERE record_id = p_record_id
    RETURNING jsonb_build_object(
        'success', TRUE,
        'message', 'OJT record deleted successfully',
        'record_id', record_id
    ) INTO v_result;
    
    IF v_result IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'OJT record not found'
        );
    END IF;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- ========== ATTENDANCE CRUD ==========

-- Create Attendance Record
CREATE OR REPLACE FUNCTION create_attendance(
    p_student_id INT,
    p_date DATE,
    p_time_in TIME,
    p_time_out TIME DEFAULT NULL,
    p_morning_in TIME DEFAULT NULL,
    p_morning_out TIME DEFAULT NULL,
    p_afternoon_in TIME DEFAULT NULL,
    p_afternoon_out TIME DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_attendance_id INT;
    v_validation JSONB;
    v_result JSONB;
BEGIN
    -- Validate attendance
    v_validation := validate_attendance(p_student_id, p_date, p_time_in, p_time_out);
    
    IF NOT (v_validation->>'is_valid')::BOOLEAN THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'errors', v_validation->'errors',
            'attendance_id', NULL
        );
    END IF;
    
    -- Insert attendance
    INSERT INTO attendance (
        student_id, date, time_in, time_out,
        morning_in, morning_out, afternoon_in, afternoon_out
    )
    VALUES (
        p_student_id, p_date, p_time_in, p_time_out,
        p_morning_in, p_morning_out, p_afternoon_in, p_afternoon_out
    )
    RETURNING attendance_id INTO v_attendance_id;
    
    RETURN jsonb_build_object(
        'success', TRUE,
        'attendance_id', v_attendance_id,
        'message', 'Attendance recorded successfully'
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'errors', ARRAY[SQLERRM],
            'attendance_id', NULL
        );
END;
$$ LANGUAGE plpgsql;

-- Get Attendance by ID
CREATE OR REPLACE FUNCTION get_attendance(p_attendance_id INT)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'attendance_id', a.attendance_id,
        'student_id', a.student_id,
        'student_name', u.full_name,
        'date', a.date,
        'time_in', a.time_in,
        'time_out', a.time_out,
        'total_hours', a.total_hours,
        'morning_in', a.morning_in,
        'morning_out', a.morning_out,
        'afternoon_in', a.afternoon_in,
        'afternoon_out', a.afternoon_out,
        'verified', a.verified,
        'created_at', a.created_at
    ) INTO v_result
    FROM attendance a
    JOIN users u ON a.student_id = u.user_id
    WHERE a.attendance_id = p_attendance_id;
    
    RETURN COALESCE(v_result, jsonb_build_object('error', 'Attendance record not found'));
END;
$$ LANGUAGE plpgsql;

-- Update Attendance Record
CREATE OR REPLACE FUNCTION update_attendance(
    p_attendance_id INT,
    p_time_in TIME DEFAULT NULL,
    p_time_out TIME DEFAULT NULL,
    p_morning_in TIME DEFAULT NULL,
    p_morning_out TIME DEFAULT NULL,
    p_afternoon_in TIME DEFAULT NULL,
    p_afternoon_out TIME DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    UPDATE attendance SET
        time_in = COALESCE(p_time_in, time_in),
        time_out = COALESCE(p_time_out, time_out),
        morning_in = COALESCE(p_morning_in, morning_in),
        morning_out = COALESCE(p_morning_out, morning_out),
        afternoon_in = COALESCE(p_afternoon_in, afternoon_in),
        afternoon_out = COALESCE(p_afternoon_out, afternoon_out),
        updated_at = CURRENT_TIMESTAMP
    WHERE attendance_id = p_attendance_id
    RETURNING jsonb_build_object(
        'success', TRUE,
        'attendance_id', attendance_id,
        'total_hours', total_hours
    ) INTO v_result;
    
    IF v_result IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Attendance record not found'
        );
    END IF;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- Delete Attendance Record
CREATE OR REPLACE FUNCTION delete_attendance(p_attendance_id INT)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    DELETE FROM attendance
    WHERE attendance_id = p_attendance_id
    RETURNING jsonb_build_object(
        'success', TRUE,
        'message', 'Attendance record deleted successfully',
        'attendance_id', attendance_id
    ) INTO v_result;
    
    IF v_result IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Attendance record not found'
        );
    END IF;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- ========== EVALUATIONS CRUD ==========

-- Create Evaluation
CREATE OR REPLACE FUNCTION create_evaluation(
    p_student_id INT,
    p_supervisor_id INT,
    p_criteria JSONB,
    p_total_score NUMERIC(5,2),
    p_feedback TEXT DEFAULT NULL,
    p_evaluation_period_start DATE DEFAULT NULL,
    p_evaluation_period_end DATE DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_eval_id INT;
    v_result JSONB;
BEGIN
    -- Validate score range
    IF p_total_score < 0 OR p_total_score > 100 THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'errors', ARRAY['Total score must be between 0 and 100'],
            'eval_id', NULL
        );
    END IF;
    
    -- Insert evaluation
    INSERT INTO evaluations (
        student_id, supervisor_id, criteria, total_score,
        feedback, evaluation_period_start, evaluation_period_end, status
    )
    VALUES (
        p_student_id, p_supervisor_id, p_criteria, p_total_score,
        p_feedback, p_evaluation_period_start, p_evaluation_period_end, 'Draft'
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
$$ LANGUAGE plpgsql;

-- Get Evaluation by ID
CREATE OR REPLACE FUNCTION get_evaluation(p_eval_id INT)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'eval_id', e.eval_id,
        'student_id', e.student_id,
        'student_name', s.full_name,
        'supervisor_id', e.supervisor_id,
        'supervisor_name', sup.full_name,
        'criteria', e.criteria,
        'total_score', e.total_score,
        'feedback', e.feedback,
        'status', e.status,
        'date_evaluated', e.date_evaluated,
        'evaluation_period_start', e.evaluation_period_start,
        'evaluation_period_end', e.evaluation_period_end
    ) INTO v_result
    FROM evaluations e
    JOIN users s ON e.student_id = s.user_id
    JOIN users sup ON e.supervisor_id = sup.user_id
    WHERE e.eval_id = p_eval_id;
    
    RETURN COALESCE(v_result, jsonb_build_object('error', 'Evaluation not found'));
END;
$$ LANGUAGE plpgsql;

-- Update Evaluation
CREATE OR REPLACE FUNCTION update_evaluation(
    p_eval_id INT,
    p_criteria JSONB DEFAULT NULL,
    p_total_score NUMERIC(5,2) DEFAULT NULL,
    p_feedback TEXT DEFAULT NULL,
    p_status VARCHAR(20) DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    -- Validate score if provided
    IF p_total_score IS NOT NULL AND (p_total_score < 0 OR p_total_score > 100) THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'errors', ARRAY['Total score must be between 0 and 100']
        );
    END IF;
    
    -- Update evaluation
    UPDATE evaluations SET
        criteria = COALESCE(p_criteria, criteria),
        total_score = COALESCE(p_total_score, total_score),
        feedback = COALESCE(p_feedback, feedback),
        status = COALESCE(p_status, status),
        updated_at = CURRENT_TIMESTAMP
    WHERE eval_id = p_eval_id
    RETURNING jsonb_build_object(
        'success', TRUE,
        'eval_id', eval_id,
        'status', status
    ) INTO v_result;
    
    IF v_result IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Evaluation not found'
        );
    END IF;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- Delete Evaluation
CREATE OR REPLACE FUNCTION delete_evaluation(p_eval_id INT)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    DELETE FROM evaluations
    WHERE eval_id = p_eval_id
    RETURNING jsonb_build_object(
        'success', TRUE,
        'message', 'Evaluation deleted successfully',
        'eval_id', eval_id
    ) INTO v_result;
    
    IF v_result IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Evaluation not found'
        );
    END IF;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- ========== AI INSIGHTS CRUD ==========

-- Create AI Insight
CREATE OR REPLACE FUNCTION create_ai_insight(
    p_student_id INT,
    p_model_name VARCHAR(50),
    p_insight_type VARCHAR(50),
    p_result JSONB,
    p_confidence NUMERIC(4,2) DEFAULT NULL,
    p_input_data JSONB DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_insight_id INT;
    v_result JSONB;
BEGIN
    INSERT INTO ai_insights (
        student_id, model_name, insight_type, result, confidence, input_data
    )
    VALUES (
        p_student_id, p_model_name, p_insight_type, p_result, p_confidence, p_input_data
    )
    RETURNING insight_id INTO v_insight_id;
    
    RETURN jsonb_build_object(
        'success', TRUE,
        'insight_id', v_insight_id,
        'message', 'AI insight created successfully'
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'errors', ARRAY[SQLERRM],
            'insight_id', NULL
        );
END;
$$ LANGUAGE plpgsql;

-- Get AI Insight by ID
CREATE OR REPLACE FUNCTION get_ai_insight(p_insight_id INT)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'insight_id', ai.insight_id,
        'student_id', ai.student_id,
        'student_name', u.full_name,
        'model_name', ai.model_name,
        'insight_type', ai.insight_type,
        'result', ai.result,
        'confidence', ai.confidence,
        'input_data', ai.input_data,
        'created_at', ai.created_at
    ) INTO v_result
    FROM ai_insights ai
    JOIN users u ON ai.student_id = u.user_id
    WHERE ai.insight_id = p_insight_id;
    
    RETURN COALESCE(v_result, jsonb_build_object('error', 'AI insight not found'));
END;
$$ LANGUAGE plpgsql;

-- Delete AI Insight
CREATE OR REPLACE FUNCTION delete_ai_insight(p_insight_id INT)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    DELETE FROM ai_insights
    WHERE insight_id = p_insight_id
    RETURNING jsonb_build_object(
        'success', TRUE,
        'message', 'AI insight deleted successfully',
        'insight_id', insight_id
    ) INTO v_result;
    
    IF v_result IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'AI insight not found'
        );
    END IF;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- ========== SYSTEM REPORTS CRUD ==========

-- Create System Report
CREATE OR REPLACE FUNCTION create_system_report(
    p_report_type VARCHAR(50),
    p_generated_by INT,
    p_content JSONB,
    p_report_period_start DATE DEFAULT NULL,
    p_report_period_end DATE DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    v_report_id INT;
    v_result JSONB;
BEGIN
    INSERT INTO system_reports (
        report_type, generated_by, content,
        report_period_start, report_period_end, status
    )
    VALUES (
        p_report_type, p_generated_by, p_content,
        p_report_period_start, p_report_period_end, 'Generated'
    )
    RETURNING report_id INTO v_report_id;
    
    RETURN jsonb_build_object(
        'success', TRUE,
        'report_id', v_report_id,
        'message', 'Report created successfully'
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'errors', ARRAY[SQLERRM],
            'report_id', NULL
        );
END;
$$ LANGUAGE plpgsql;

-- Get System Report by ID
CREATE OR REPLACE FUNCTION get_system_report(p_report_id INT)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'report_id', r.report_id,
        'report_type', r.report_type,
        'generated_by', r.generated_by,
        'generated_by_name', u.full_name,
        'content', r.content,
        'status', r.status,
        'report_period_start', r.report_period_start,
        'report_period_end', r.report_period_end,
        'created_at', r.created_at
    ) INTO v_result
    FROM system_reports r
    JOIN users u ON r.generated_by = u.user_id
    WHERE r.report_id = p_report_id;
    
    RETURN COALESCE(v_result, jsonb_build_object('error', 'Report not found'));
END;
$$ LANGUAGE plpgsql;

-- Delete System Report
CREATE OR REPLACE FUNCTION delete_system_report(p_report_id INT)
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    DELETE FROM system_reports
    WHERE report_id = p_report_id
    RETURNING jsonb_build_object(
        'success', TRUE,
        'message', 'Report deleted successfully',
        'report_id', report_id
    ) INTO v_result;
    
    IF v_result IS NULL THEN
        RETURN jsonb_build_object(
            'success', FALSE,
            'error', 'Report not found'
        );
    END IF;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- END OF STORED PROCEDURES AND FUNCTIONS
-- =====================================================

-- Grant execute permissions (adjust as needed)
-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO your_app_user;

