from flask import Flask, request, jsonify, Response, stream_with_context
from flask_cors import CORS
from chatbot_handler import chatbot_response
from competency_handler import suggest_competency
from insight_engine import predict_with_explanation, predict_performance, build_features_from_snapshot
from face_engine import verify_faces
import re
import time
from flask import g

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

def format_response(text):
    """
    Format chatbot response for better presentation while preserving markdown:
    - Improve paragraph spacing
    - Ensure bullet points and lists are well-defined
    """
    if not text:
        return text
    
    # Normalize whitespace (avoid double-triple newlines but keep paragraph breaks)
    text = re.sub(r'\n{3,}', '\n\n', text)
    
    # Ensure spacing around bullet points if they aren't already spaced
    text = re.sub(r'([^\n])\n([-•*])\s', r'\1\n\n\2 ', text)
    
    # Ensure spacing around headers
    text = re.sub(r'([^\n])\n([#]+)', r'\1\n\n\2', text)
    
    return text.strip()

@app.route('/greeting', methods=['GET', 'POST'])
def greeting():
    """
    Greeting endpoint that returns the initial greeting message.
    
    Returns:
    {
        "success": true,
        "answer": "<greeting message>",
        "is_fallback": false,
        "session_id": "<session id>",
        "used_context": [],
        "confidence_score": 1.0,
        "error_type": null,
        "message": null
    }
    """
    try:
        greeting_text = (
            "Hello. I am the JRMSU OJT Assistant. I can provide formal information about JRMSU, "
            "the OJT program, requirements, procedures, and related university guidelines. "
            "How can I help you today?"
        )
        
        # Get or generate session ID
        session_id = None
        if request.method == 'POST':
            data = request.get_json() or {}
            session_id = data.get("session_id")
        
        session_id = session_id or "default"
        
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

                ollama_url = os.getenv("OLLAMA_URL", "http://127.0.0.1:11434/api/generate")
                ollama_model = os.getenv("OLLAMA_MODEL", "gemma2:2b")

                # Build a context-aware prompt using chatbot_handler's RAG retrieval
                from chatbot_handler import get_rag_context
                context = get_rag_context(user_message)
                
                # If no specific context found, add a general university context
                if "No specific context found" in context:
                    context = (
                        "JRMSU (Jose Rizal Memorial State University) OJT Program overview:\n"
                        "- Primary focus: Providing hands-on industry experience for students.\n"
                        "- Requirements: DTR, Narrative Report, Evaluation forms.\n"
                        "- Goal: Develop learning competencies in various IT and engineering fields."
                    )
                
                prompt = (
                    f"System: You are the JRMSU OJT AI Assistant. You answer ONLY based on the provided JRMSU Context. "
                    f"You must refuse to answer any questions that are not related to JRMSU OJT or the provided context.\n"
                    f"Context:\n{context}\n\n"
                    f"Instruction: Answer the student's question ONLY using information from the context above. "
                    f"If the information is not present, say: 'I'm sorry, my current JRMSU knowledge doesn't cover that topic. Please consult your OJT coordinator.'\n\n"
                    f"Student: {user_message}\nAssistant:"
                )

                accumulated = ""
                try:
                    with req_lib.post(
                        ollama_url,
                        json={"model": ollama_model, "prompt": prompt, "stream": True},
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
                                    "answer": accumulated,
                                    "is_streaming": not done,
                                    "session_id": session_id or "default",
                                    "is_fallback": False,
                                    "confidence_score": 1.0,
                                    "used_context": []
                                }) + "\n"
                                if done:
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

        from insight_engine import predict_with_explanation, call_gemma_stream
        from flask import Response, stream_with_context
        import json

        # Step 1: Pre-calculate the prompt using standard logic (trivially small latency)
        # We'll use a simplified version for the stream or just reuse insight_engine logic.
        # For simplicity, we'll implement the generator here.
        
        def generate():
            # First, get the static ML result (which is fast)
            # We bypass the full Gemma wait by using call_gemma_stream
            
            # This is a bit complex to do in one go, so let's use the insight_engine 
            # to get the ML result first, then stream the narrative.
            ml_and_context = predict_with_explanation(student_data, include_gemma=False)
            
            # Yield the static JSON first (ML result, grading, integrity)
            yield json.dumps({"type": "metadata", "data": ml_and_context}) + "\n--CHUNK--\n"
            
            # Yield the AI narrative chunks
            # Construct the prompt manually or use a helper
            prompt = f"Student performance summary for {student_data.get('student_name', 'Student')}:\n- Risk: {ml_and_context['risk_level']}\n- Recommendations: ..."
            # Note: In a real refactor, I'd move prompt construction to a shared helper.
            # Using basic prompt for now as a proof of concept.
            
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
