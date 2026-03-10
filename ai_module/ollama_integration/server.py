from flask import Flask, request, jsonify
from flask_cors import CORS
from chatbot_handler import chatbot_response
from insight_engine import predict_with_explanation, predict_performance, build_features_from_snapshot
import re

app = Flask(__name__)
CORS(app)  # ✅ Enables communication with Flutter (web or mobile)

def format_response(text):
    """
    Format chatbot response for better presentation:
    - Convert numbered lists to markdown
    - Convert bullet points to markdown
    - Format code blocks
    - Improve paragraph spacing
    """
    if not text:
        return text
    
    # Normalize whitespace
    text = re.sub(r'\n{3,}', '\n\n', text)
    
    # Convert numbered lists (1. 2. 3.) to markdown
    text = re.sub(r'^(\d+)\.\s+(.+)$', r'\1. \2', text, flags=re.MULTILINE)
    
    # Convert bullet points (- or •) to markdown
    text = re.sub(r'^[-•]\s+(.+)$', r'- \1', text, flags=re.MULTILINE)
    
    # Format code-like patterns (backticks or indented blocks)
    text = re.sub(r'`([^`]+)`', r'`\1`', text)
    
    # Format URLs
    text = re.sub(
        r'(https?://[^\s]+)',
        r'[\1](\1)',
        text
    )
    
    # Ensure proper spacing around headers
    text = re.sub(r'\n([#]+)', r'\n\n\1', text)
    
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
        
        # Use hybrid ML + Gemma prediction (now with built-in validation)
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

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
