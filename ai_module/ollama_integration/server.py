from flask import Flask, request, jsonify, Response, stream_with_context, g
from flask_cors import CORS
from chatbot_handler import chatbot_response, get_rag_context
from run_ai import format_response, build_prompt_with_context
from competency_handler import suggest_competency
from insight_engine import predict_with_explanation, call_gemma_stream
from face_engine import verify_faces
import json
import time

app = Flask(__name__)
CORS(app)  # ✅ Enables communication with Flutter (web or mobile)

@app.before_request
def start_timer():
    g.start = time.time()

@app.after_request
def log_request(response):
    if hasattr(g, 'start'):
        duration = (time.time() - g.start) * 1000
        print(f"[API] {request.method} {request.path} - {response.status_code} - {duration:.2f}ms")
    return response



@app.route('/greeting', methods=['GET', 'POST'])
def greeting():
    """
    Greeting endpoint that returns a role-aware initial greeting message.
    
    Expected JSON request (POST):
    {
        "session_id": "<optional session identifier>",
        "role": "<optional user role: student|supervisor|coordinator|admin>"
    }
    
    Returns:
    {
        "success": true,
        "answer": "<role-aware greeting message>",
        "is_fallback": false,
        "session_id": "<session id>",
        "used_context": [],
        "confidence_score": 1.0,
        "error_type": null,
        "message": null
    }
    """
    try:
        # Get session ID and role from request
        session_id = None
        role = ""
        if request.method == 'POST':
            data = request.get_json() or {}
            session_id = data.get("session_id")
            role = (data.get("role") or "").lower().strip()
        
        session_id = session_id or "default"
        
        # Role-aware greeting
        from chatbot_handler import _get_role_greeting
        greeting_text = _get_role_greeting(role)
        
        return jsonify({
            "success": True,
            "answer": greeting_text,
            "is_fallback": False,
            "session_id": session_id,
            "used_context": [],
            "confidence_score": 1.0,
            "error_type": None,
            "message": None
        }), 200
        
    except Exception as e:
        import traceback
        print(f"[GREETING ERROR] Unexpected exception: {traceback.format_exc()}")
        return jsonify({
            "success": False,
            "error_type": "CHATBOT_SERVICE_UNAVAILABLE",
            "message": "Unable to load greeting message.",
            "answer": None,
            "session_id": session_id if 'session_id' in locals() else "default",
            "is_fallback": False,
            "used_context": [],
            "confidence_score": 0.0
        }), 500

@app.route('/chat', methods=['POST'])
def chat():
    """
    Chatbot endpoint with conversation context support.
    
    Expected JSON request:
    {
        "message": "<user message>",
        "session_id": "<optional session identifier>"
    }
    
    Returns (on success):
    {
        "success": true,
        "answer": "<bot response>",
        "is_fallback": false,
        "session_id": "<session id>",
        "used_context": ["<snippet 1>", "<snippet 2>", ...],
        "confidence_score": 0.85,
        "error_type": null,
        "message": null
    }
    
    Returns (on error):
    {
        "success": false,
        "error_type": "CHATBOT_SERVICE_UNAVAILABLE" | "INVALID_INPUT" | "EMBEDDING_ERROR" | "RETRIEVAL_ERROR" | "LLM_ERROR",
        "message": "Human-readable error message",
        "answer": null,
        "session_id": "<session id>",
        "is_fallback": false,
        "used_context": [],
        "confidence_score": 0.0
    }
    
    Note: If is_fallback is true, the answer is a low-confidence response
    and the user should consult their OJT coordinator for confirmation.
    """
    try:
        data = request.get_json() or {}
        user_message = data.get("message", "")
        session_id = data.get("session_id")  # Optional: frontend can provide or let backend generate
        student_data = data.get("student_data") # Optional data dict
        
        print(f"[CHAT] Received message: {user_message[:100]}...")  # Log first 100 chars
        print(f"[CHAT] Session ID: {session_id or 'default'}")
        print(f"[CHAT] student_data present: {student_data is not None}, type: {type(student_data).__name__}")
        if student_data:
            print(f"[CHAT] student_data keys: {list(student_data.keys()) if isinstance(student_data, dict) else 'NOT A DICT'}")
            print(f"[CHAT] student_data role: {student_data.get('role', 'MISSING') if isinstance(student_data, dict) else 'N/A'}")
        
        if not user_message:
            return jsonify({
                "success": False,
                "error_type": "INVALID_INPUT",
                "message": "Please enter a message.",
                "answer": None,
                "session_id": session_id or "default",
                "is_fallback": False,
                "used_context": [],
                "confidence_score": 0.0
            }), 400
        
        should_stream = data.get("stream", False)
        
        if should_stream:
            print(f"[CHAT] Starting TRUE Ollama token stream for: {user_message[:50]}...")
            def generate():
                import json
                import requests as req_lib
                import os
                import datetime
                from chatbot_context import get_context_manager
                from chatbot_handler import (
                    _is_ojt_related, _build_role_system_instruction,
                    _get_role_greeting, OJT_DECLINE_MESSAGE,
                    _generate_student_summary, _generate_coordinator_summary,
                    _generate_supervisor_summary, _generate_admin_summary,
                    _validate_role,          # GAP 2b FIX — role escalation guard
                )
                from run_ai import build_system_message  # GAP 6b FIX — unified system msg

                # ── OJT Topic Guard for streaming ──
                if not _is_ojt_related(user_message):
                    yield json.dumps({
                        "success": True,
                        "answer": OJT_DECLINE_MESSAGE,
                        "is_streaming": False,
                        "session_id": session_id or "default",
                        "is_fallback": False,
                        "confidence_score": 1.0,
                        "used_context": []
                    }) + "\n"
                    return

                # ── Handle greetings inline ──
                greeting_patterns = [
                    "hi", "hello", "hey", "good morning", "good afternoon",
                    "good evening", "greetings", "hi there", "hello there"
                ]
                msg_lower = user_message.lower().strip()
                if msg_lower in greeting_patterns or any(msg_lower.startswith(g) for g in greeting_patterns):
                    role_g = (student_data or {}).get('role', '') if student_data else ''
                    greeting = _get_role_greeting(role_g.lower())
                    yield json.dumps({
                        "success": True,
                        "answer": greeting,
                        "is_streaming": False,
                        "session_id": session_id or "default",
                        "is_fallback": False,
                        "confidence_score": 1.0,
                        "used_context": []
                    }) + "\n"
                    return

                ollama_url = os.getenv("OLLAMA_URL", "http://127.0.0.1:11434/api/generate")
                ollama_model = os.getenv("OLLAMA_MODEL", "gemma2:2b")

                # 1. Get RAG context using unified logic
                context_snippets = get_rag_context(user_message)

                # 2. Get conversation history if session exists
                history = []
                if session_id:
                    ctx = get_context_manager().get_context(session_id)
                    if ctx:
                        ctx.add_user_message(user_message)
                        history = ctx.get_recent_history(max_turns=5)

                # 3. Build role-aware instruction + dashboard context from student_data
                # GAP 2b FIX — validate role against whitelist before use
                raw_role = (student_data or {}).get('role', '') if student_data else ''
                role = _validate_role(raw_role) if student_data else ''
                role_instruction = _build_role_system_instruction(role, student_data) if role else None

                dashboard_context = ""
                if student_data:
                    try:
                        if role == 'coordinator' or "total_students" in student_data:
                            dashboard_context = _generate_coordinator_summary(student_data)
                        elif role == 'admin' or "total_users" in student_data:
                            dashboard_context = _generate_admin_summary(student_data)
                        elif role in ('supervisor', 'industry supervisor') or "total_assigned" in student_data:
                            dashboard_context = _generate_supervisor_summary(student_data)
                        elif role == 'student' or "hours" in student_data:
                            dashboard_context = _generate_student_summary(student_data)
                        print(f"[CHAT] Dashboard context built for role '{role}' ({len(dashboard_context)} chars)")
                    except Exception as e:
                        print(f"[CHAT] Warning: Failed to build dashboard context: {e}")

                # 4. Build enriched query WITH dashboard data (this was the missing piece)
                if dashboard_context:
                    current_time_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                    enriched_message = (
                        f"[SYSTEM CONTEXT]\n"
                        f"Current Local Time: {current_time_str}\n"
                        f"{dashboard_context}\n\n"
                        f"User Question: {user_message}"
                    )
                else:
                    enriched_message = user_message

                # 5. Build the official prompt with enriched message (not raw user_message)
                print(f"[CHAT_DEBUG] enriched_message has [SYSTEM CONTEXT]: {'[SYSTEM CONTEXT]' in enriched_message}")
                print(f"[CHAT_DEBUG] enriched_message length: {len(enriched_message)}")
                print(f"[CHAT_DEBUG] first 400 chars: {enriched_message[:400]}")
                prompt = build_prompt_with_context(
                    enriched_message, context_snippets,
                    conversation_history=history,
                    role_instruction=role_instruction
                )

                # 6. Build role-aware system message using the SHARED builder
                # GAP 6b FIX — identical persona whether streaming or non-streaming
                system_msg = build_system_message(role_instruction)

                accumulated = ""
                try:
                    with req_lib.post(
                        ollama_url,
                        json={
                            "model": ollama_model,
                            "prompt": prompt,
                            "system": system_msg,
                            "stream": True
                        },
                        stream=True,
                        timeout=120
                    ) as r:
                        for raw_line in r.iter_lines():
                            if not raw_line:
                                continue
                            try:
                                chunk = json.loads(raw_line.decode("utf-8"))
                                token = chunk.get("response", "")
                                accumulated += token
                                done = chunk.get("done", False)
                                yield json.dumps({
                                    "success": True,
                                    "answer": format_response(accumulated),
                                    "is_streaming": not done,
                                    "session_id": session_id or "default",
                                    "is_fallback": False,
                                    "confidence_score": 1.0,
                                    "used_context": [context_snippets[:200] + "..."] if context_snippets else []
                                }) + "\n"
                                if done:
                                    # Save assistant response to conversation context
                                    if session_id:
                                        try:
                                            ctx2 = get_context_manager().get_context(session_id)
                                            if ctx2:
                                                ctx2.add_assistant_message(accumulated)
                                        except Exception:
                                            pass
                                    break
                            except Exception:
                                continue
                except Exception as e:
                    yield json.dumps({
                        "success": False,
                        "error_type": "LLM_ERROR",
                        "message": f"Streaming error: {str(e)}",
                        "answer": None,
                        "session_id": session_id or "default",
                        "is_fallback": False,
                        "used_context": [],
                        "confidence_score": 0.0
                    }) + "\n"

            return Response(stream_with_context(generate()), mimetype='application/x-ndjson')

        # Get structured response from chatbot handler
        print("[CHAT] Calling chatbot_response (JRMSU OJT Assistant from run_ai.py)...")
        result = chatbot_response(user_message, session_id=session_id, student_data=student_data)
        
        # Check if request was successful
        if result.get("success"):
            # Format the answer for better presentation (keep markdown formatting for frontend)
            answer = result.get("answer", "")
            if answer:
                # Apply formatting (but preserve markdown for frontend rendering)
                formatted_answer = format_response(answer)
                result["answer"] = formatted_answer
            
            print(f"[CHAT] Response generated successfully. Fallback: {result.get('is_fallback', False)}")
            print(f"[CHAT] Answer length: {len(result.get('answer', ''))} characters")
            
            # Return successful response
            return jsonify(result), 200
        else:
            # Handle error response
            error_type = result.get("error_type", "CHATBOT_SERVICE_UNAVAILABLE")
            
            # Map error types to HTTP status codes
            status_code_map = {
                "INVALID_INPUT": 400,
                "CHATBOT_SERVICE_UNAVAILABLE": 503,
                "KNOWLEDGE_BASE_ERROR": 503,
                "EMBEDDING_ERROR": 503,
                "RETRIEVAL_ERROR": 503,
                "LLM_ERROR": 503
            }
            
            status_code = status_code_map.get(error_type, 500)
            
            print(f"[CHAT] Error response: {error_type} - {result.get('message', '')}")
            
            return jsonify(result), status_code
        
    except Exception as e:
        # Unexpected exception (shouldn't happen with new error handling, but keep as safety net)
        error_msg = str(e)
        import traceback
        print(f"[CHAT ERROR] Unexpected exception: {error_msg}")
        print(f"[CHAT ERROR] Traceback: {traceback.format_exc()}")
        
        return jsonify({
            "success": False,
            "error_type": "CHATBOT_SERVICE_UNAVAILABLE",
            "message": "The chatbot service encountered an unexpected error. Please try again later or contact your coordinator.",
            "answer": None,
            "session_id": data.get("session_id") if 'data' in locals() else "default",
            "is_fallback": False,
            "used_context": [],
            "confidence_score": 0.0
        }), 500

@app.route('/predict', methods=['POST'])
def predict():
    """
    Comprehensive Multi-Feature OJT Performance Prediction Endpoint.
    
    This endpoint uses a rich feature set including:
    - Attendance metrics (approved only)
    - Competency-based daily task data (11 competencies)
    - OJT grading components (WPR 20%, NR 20%, CE 20%, SE 40%)
    - Chatbot engagement metrics
    
    Expected JSON snapshot (comprehensive 30+ features):
    {
        "total_hours_completed": 150.0,
        "required_hours": 300,
        "attendance_rate": 75.0,
        "late_count": 2,
        "absent_count": 5,
        "hours_completed_ratio": 0.5,
        "total_tasks_logged": 20,
        "total_task_hours": 80.0,
        "number_of_distinct_competencies": 5,
        "hours_software_development": 40.0,
        "hours_machine_learning_engineering": 0.0,
        "hours_it_related_research": 0.0,
        "hours_ux_ui_design": 0.0,
        "hours_information_security_analysis": 0.0,
        "hours_networking": 0.0,
        "hours_technical_support": 10.0,
        "hours_data_analysis": 0.0,
        "hours_customer_service": 0.0,
        "hours_data_entry_management": 0.0,
        "hours_office_work": 30.0,
        "weekly_progress_grade": 85.0,
        "narrative_report_grade": 80.0,
        "coordinator_eval_grade": 88.0,
        "supervisor_eval_grade": 90.0,  // May be 0 during active OJT
        "has_weekly_progress_grade": 1,
        "has_narrative_report_grade": 1,
        "has_coordinator_eval_grade": 1,
        "has_supervisor_eval_grade": 1,  // May be 0 during active OJT
        "total_chatbot_queries": 15,
        "chatbot_queries_last_30_days": 8
    }
    
    Note: Supervisor evaluation may be missing (0) during active OJT.
    The model handles this gracefully using other available indicators.
    
    Returns (on success):
    {
        "success": true,
        "ml_prediction": {
            "risk_level": "HIGH" | "MEDIUM" | "LOW",
            "predicted_label": <string>,
            "probability": <float>,
            "probabilities": { <label>: prob, ... },
            "top_reasons": [...],
            "recommendation": "..."
        },
        "gemma_explanation": <string>,
        "gemma_recommendations": [<list of strings>]
    }
    
    Returns (on error):
    {
        "success": false,
        "error_type": "MODEL_NOT_AVAILABLE" | "INVALID_INPUT" | "PREDICTION_ERROR",
        "message": "Human-readable error message",
        "details": "Technical details (optional)",
        "missing_fields": [...] (if INVALID_INPUT)
    }
    """
    try:
        data = request.get_json() or {}
        
        # Log summary of incoming payload for observability (Point-based check)
        print(f"[PREDICT] Received request for: {data.get('student_name', 'Unknown')}")
        print(f"[PREDICT] Hour Metrics: completed={data.get('total_hours_completed')}, required={data.get('required_hours')}")
        print(f"[PREDICT] Competency Samples: software={data.get('hours_software_development')}, it_related={data.get('hours_it_related_research')}")
        
        # Use hybrid ML + Gemma prediction
        result = predict_with_explanation(data)
        
        # Check if prediction was successful
        if result.get("success", False):
            return jsonify(result), 200
        else:
            # Handle error responses
            error_type = result.get("error_type", "PREDICTION_ERROR")
            
            # Map error types to HTTP status codes
            status_code_map = {
                "MODEL_NOT_AVAILABLE": 503,  # Service Unavailable
                "INVALID_INPUT": 400,         # Bad Request
                "PREDICTION_ERROR": 500       # Internal Server Error
            }
            
            status_code = status_code_map.get(error_type, 500)
            return jsonify(result), status_code
            
    except Exception as e:
        # Unexpected exception (shouldn't happen with new error handling, but keep as safety net)
        import traceback
        print(f"[PREDICT ERROR] Unexpected exception: {traceback.format_exc()}")
        return jsonify({
            "success": False,
            "error_type": "PREDICTION_ERROR",
            "message": "An unexpected error occurred during prediction.",
            "details": str(e)
        }), 500

@app.route('/predict-stream', methods=['POST'])
def predict_stream():
    """
    Streaming AI Performance Prediction Endpoint.
    Yields full ML metadata as the first chunk, followed by the AI narrative tokens.
    """
    try:
        data = request.get_json() or {}
        student_data = data.get("student_data")
        
        if not student_data:
            return jsonify({"success": False, "error": "No student data provided"}), 400

        def generate():
            # Get the static ML result first (fast, no LLM call)
            ml_and_context = predict_with_explanation(student_data, include_gemma=False)
            
            # Yield the static JSON first (ML result, grading, integrity)
            yield json.dumps({"type": "metadata", "data": ml_and_context}) + "\n--CHUNK--\n"
            
            # Stream the AI narrative tokens
            prompt = f"Student performance summary for {student_data.get('student_name', 'Student')}:\n- Risk: {ml_and_context['risk_level']}\n- Recommendations: ..."
            
            for token in call_gemma_stream(prompt):
                yield json.dumps({"type": "token", "content": token}) + "\n--CHUNK--\n"

        return Response(stream_with_context(generate()), mimetype='application/json-stream')

    except Exception as e:
        import traceback
        print(f"[PREDICT-STREAM ERROR] {traceback.format_exc()}")
        return jsonify({"success": False, "error": str(e)}), 500

@app.route('/suggest-competency', methods=['POST'])
def suggest():
    """
    AI Competency Suggestion Endpoint.
    Analyzes task description and returns the best matching official OJT competency.
    """
    try:
        data = request.get_json() or {}
        description = data.get("description", "")
        
        if not description:
            return jsonify({
                "success": False,
                "error": "Task description is required"
            }), 400
            
        suggestion = suggest_competency(description)
        
        return jsonify({
            "success": True,
            "suggestion": suggestion,
            "description": description
        }), 200
        
    except Exception as e:
        print(f"[SUGGEST ERROR] {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@app.route('/ai/suggest-remark', methods=['POST'])
def suggest_remark():
    """
    AI Remark Suggestion Endpoint for Supervisors.
    Given a task description and competency, returns a 1-sentence professional remark.
    """
    try:
        import requests as req_lib, os, json
        data = request.get_json() or {}
        task_desc = data.get("task_description", "").strip()
        competency = data.get("competency", "").strip()

        if not task_desc:
            return jsonify({"success": False, "error": "task_description is required"}), 400

        ollama_url = os.getenv("OLLAMA_URL", "http://127.0.0.1:11434/api/generate")
        ollama_model = os.getenv("OLLAMA_MODEL", "gemma2:2b")

        comp_str = f" under the '{competency}' competency" if competency else ""
        prompt = (
            f"Write exactly ONE professional, concise supervisor remark (1 sentence, max 20 words) "
            f"for the following OJT daily task{comp_str}. "
            f"Be specific, encouraging, and professional. Do not repeat the task. "
            f"Task: {task_desc}\nRemark:"
        )

        resp = req_lib.post(
            ollama_url,
            json={"model": ollama_model, "prompt": prompt, "stream": False},
            timeout=30
        )
        resp.raise_for_status()
        suggestion = resp.json().get("response", "").strip().split("\n")[0]
        # Trim to the first sentence
        for punct in [".", "!", "?"]:
            idx = suggestion.find(punct)
            if idx != -1:
                suggestion = suggestion[:idx+1]
                break

        print(f"[SUGGEST-REMARK] Generated: {suggestion}")
        return jsonify({"success": True, "suggestion": suggestion}), 200

    except Exception as e:
        print(f"[SUGGEST-REMARK ERROR] {e}")
        return jsonify({"success": False, "error": str(e)}), 500


@app.route('/verify-face', methods=['POST'])
def verify_face_route():
    """
    AI Face Verification Endpoint.
    Compares attendance photo with profile photo.
    """
    try:
        data = request.get_json() or {}
        attendance_photo = data.get("attendance_photo")
        profile_photo = data.get("profile_photo")

        if not attendance_photo or not profile_photo:
            return jsonify({
                "success": False,
                "error": "Both attendance_photo and profile_photo are required"
            }), 400

        result = verify_faces(attendance_photo, profile_photo)
        
        status_code = 200 if result.get("success") else 500
        return jsonify(result), status_code

    except Exception as e:
        print(f"[VERIFY-FACE ERROR] {e}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, threaded=True)
