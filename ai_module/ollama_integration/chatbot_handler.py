"""
Chatbot handler wrapper for the JRMSU OJT Assistant.

This module wraps the RAG-based chatbot implementation located in jrmsu_ojt_chatbot/
and provides the chatbot_response function interface expected by server.py.

It now includes:
- Session-based conversation context management
- Structured error handling
- Fallback detection
"""

import os
import sys
import logging
import traceback
from typing import Dict, Any, Optional

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Determine the current directory (where this file is located)
current_dir = os.path.dirname(os.path.abspath(__file__))

# Build the path to jrmsu_ojt_chatbot directory
jrmsu_dir = os.path.join(current_dir, "jrmsu_ojt_chatbot")

# Add jrmsu_ojt_chatbot to sys.path if it isn't already there
if jrmsu_dir not in sys.path:
    sys.path.insert(0, jrmsu_dir)

# Import the generate_response function from run_ai
from run_ai import generate_response

# Patch BASE_KNOWLEDGE_DIR to use absolute path
# This is needed because run_ai.py uses relative paths
import run_ai
run_ai.BASE_KNOWLEDGE_DIR = os.path.join(jrmsu_dir, "data", "jrmsu_knowledge")

# Import context manager
from chatbot_context import get_context_manager
from career_engine import generate_career_briefing
from insight_engine import predict_performance, build_features_from_snapshot

def _detect_intent(text: str) -> str:
    """Detect the high-level intent of the user message."""
    text_lower = text.lower()
    
    performance_keywords = ["performance", "risk", "score", "grade", "forecast", "prediction", "how am i doing", "status"]
    if any(k in text_lower for k in performance_keywords):
        return "PERFORMANCE"
        
    attendance_keywords = ["attendance", "dtr", "hours", "late", "absent", "log"]
    if any(k in text_lower for k in attendance_keywords):
        return "ATTENDANCE"
        
    requirements_keywords = ["requirement", "journal", "documentation", "submission", "deadline"]
    if any(k in text_lower for k in requirements_keywords):
        return "REQUIREMENTS"
        
    dashboard_keywords = ["dashboard", "my progress", "my stats", "hours", "total students", "risk", "status", "pending", "evaluation"]
    if any(k in text_lower for k in dashboard_keywords):
        return "DASHBOARD"
        
    return "GENERAL"


def _generate_student_summary(data: Dict) -> str:
    """Generate an explanatory summary for a student's dashboard data."""
    hours = data.get('hours', {})
    completed = hours.get('completed', 0)
    required = hours.get('required', 300)
    
    attendance = data.get('attendance', {})
    present = attendance.get('days_present', 0)
    
    tasks = data.get('daily_tasks', {})
    done = tasks.get('completed_tasks', 0)
    
    ai = data.get('ai_insight', {})
    score = ai.get('score', 0)
    risk = ai.get('risk_level', 'Unknown')

    summary = (
        f"\nStudent OJT Dashboard Analysis:\n"
        f"- Progress: The student has completed {completed} out of {required} required hours.\n"
        f"- Attendance: They have been marked present for {present} days.\n"
        f"- Task Completion: {done} daily tasks have been successfully submitted and verified.\n"
        f"- AI Performance: The AI engine assigns a performance score of {score}/100 with a '{risk}' risk level.\n"
    )
    return summary


def _generate_coordinator_summary(data: Dict) -> str:
    """Generate an explanatory summary for a coordinator's dashboard data."""
    summary = (
        f"\nCoordinator System Overview Analysis:\n"
        f"- Student Base: There are currently {data.get('total_students', 0)} students under supervision.\n"
        f"- Risk Monitoring: {data.get('high_risk_students', 0)} students are flagged as High Risk, {data.get('medium_risk_students', 0)} as Medium Risk, and {data.get('low_risk_students', 0)} as Low Risk.\n"
        f"- OJT Status: {data.get('active_ojt', 0)} students are actively on-site, while {data.get('completed_ojt', 0)} have finished their requirements.\n"
        f"- Performance Metrics: The system-wide average attendance rate is {data.get('average_attendance', 0):.1f}%, with an average completion ratio of {data.get('average_completion', 0):.1f}%.\n"
        f"- Grading: The average forecasted grade for the current batch is {data.get('average_forecast_grade', 'N/A')}.\n"
    )
    return summary


def _generate_supervisor_summary(data: Dict) -> str:
    """Generate an explanatory summary for a supervisor's dashboard data."""
    summary = (
        f"\nIndustry Supervisor Dashboard Analysis:\n"
        f"- Assigned Students: You are currently managing {data.get('total_assigned', 0)} OJT students.\n"
        f"- Pending Actions: There are {data.get('pending_evaluations', 0)} performance evaluations awaiting your review.\n"
        f"- Student Welfare: {data.get('high_risk_students', 0)} students under your care are flagged as needing immediate academic or behavioral attention.\n"
        f"- Performance Trend: The average forecast score for your assigned students is {data.get('average_forecast_score', 'N/A')}.\n"
    )
    return summary


def _generate_admin_summary(data: Dict) -> str:
    """Generate an explanatory summary for an admin's dashboard data."""
    summary = (
        f"\nSystem Administration Overview:\n"
        f"- User Population: The platform has {data.get('total_users', 0)} total registered users.\n"
        f"- Active Engagement: {data.get('active_users', 0)} users are currently active and verified.\n"
        f"- Onboarding Queue: {data.get('pending_users', 0)} new registrations are awaiting administrative approval.\n"
        f"- Staffing: There are {data.get('coordinator_count', 0)} registered OJT coordinators managing the students.\n"
    )
    return summary


def chatbot_response(
    user_message: str,
    session_id: Optional[str] = None,
    student_data: Optional[Dict] = None
) -> Dict[str, Any]:
    """
    Enhanced chatbot response handler with conversation context support.
    
    This function handles the full chatbot pipeline including:
    - Session management and conversation history
    - RAG-based answer generation
    - Error handling and fallback responses
    - Structured response formatting
    
    Args:
        user_message: The user's input message
        session_id: Optional session identifier for conversation context.
                    If None, uses a default session or creates a temporary one.
    
    Returns:
        Dictionary with structured response:
        {
            "success": bool,
            "answer": str | None,
            "is_fallback": bool,
            "session_id": str,
            "used_context": List[str],
            "confidence_score": float,
            "error_type": str | None,
            "message": str | None
        }
        
        On error:
        {
            "success": False,
            "error_type": "CHATBOT_SERVICE_UNAVAILABLE" | "INVALID_INPUT" | ...,
            "message": "Human-readable error message",
            "answer": None,
            "session_id": session_id,
            "is_fallback": False,
            "used_context": [],
            "confidence_score": 0.0
        }
    """
    # Basic input validation
    text = (user_message or "").strip()
    if not text:
        return {
            "success": False,
            "error_type": "INVALID_INPUT",
            "message": "Please type a message so I can help you.",
            "answer": None,
            "session_id": session_id or "default",
            "is_fallback": False,
            "used_context": [],
            "confidence_score": 0.0
        }
    
    # Check for simple greetings - return friendly response without RAG
    greeting_patterns = [
        "hi", "hello", "hey", "good morning", "good afternoon", 
        "good evening", "greetings", "hi there", "hello there"
    ]
    text_lower = text.lower().strip()
    if text_lower in greeting_patterns or any(text_lower.startswith(g) for g in greeting_patterns):
        logger.info(f"[CHATBOT_HANDLER] Detected greeting: {text}")
        return {
            "success": True,
            "answer": "Hello! How can I help you today?",
            "is_fallback": False,
            "session_id": session_id or "default",
            "used_context": [],
            "confidence_score": 1.0,
            "error_type": None,
            "message": None
        }
    
    # Get or create session context
    session_id = session_id or "default"
    context_manager = get_context_manager()
    
    try:
        context = context_manager.get_or_create_context(session_id)
        
        # Add user message to context
        context.add_user_message(text)
        
        # Get conversation history for context-aware responses
        conversation_history = context.get_recent_history(max_turns=5)
        
        # Detect intent
        intent = _detect_intent(text)
        logger.info(f"[CHATBOT_HANDLER] Detected intent: {intent}")
        
        # Inject dashboard/performance context if provided
        dashboard_context = ""
        if student_data:
            try:
                # Explicit role-based detection first
                role = student_data.get('role', '').lower()
                
                if role == 'coordinator' or "total_students" in student_data:
                    dashboard_context = _generate_coordinator_summary(student_data)
                elif role == 'admin' or "total_users" in student_data:
                    dashboard_context = _generate_admin_summary(student_data)
                elif role == 'supervisor' or "total_assigned" in student_data:
                    dashboard_context = _generate_supervisor_summary(student_data)
                elif role == 'student' or "hours" in student_data:
                    dashboard_context = _generate_student_summary(student_data)
                else:
                    # Fallback for generic "User" role if data is present
                    dashboard_context = f"\nUser Dashboard Info: {str(student_data)}\n"
                
                # Also include career briefing if it's a student
                if "hours" in student_data:
                    try:
                        career_briefing = generate_career_briefing(student_data)
                        dashboard_context = career_briefing + dashboard_context
                    except Exception as e:
                        logger.debug(f"Career briefing skipped: {e}")

                if dashboard_context:
                    import datetime
                    # Get local time from the environment/server, formatted for PHT if possible
                    # Since we're in AGENT context, we can use the provided metadata time
                    current_time_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                    
                    text_for_llm = (
                        f"[SYSTEM CONTEXT]\n"
                        f"Current Local Time: {current_time_str}\n"
                        f"{dashboard_context}\n\n"
                        f"User Question: {text}"
                    )
                else:
                    text_for_llm = text
            except Exception as ce:
                logger.error(f"[CHATBOT_HANDLER] Error generating dashboard summary: {ce}")
                text_for_llm = text
        else:
            text_for_llm = text
        
        logger.info(f"[CHATBOT_HANDLER] Processing message for session {session_id}")
        logger.debug(f"[CHATBOT_HANDLER] Message: {text[:100]}...")
        logger.debug(f"[CHATBOT_HANDLER] Conversation history: {len(conversation_history)} messages")
        
        # Call the RAG pipeline with conversation context
        result = generate_response(text_for_llm, conversation_history=conversation_history)
        
        # Add assistant response to context if successful
        if result.get("success") and result.get("answer"):
            context.add_assistant_message(result["answer"])
        
        # Add session_id to response
        result["session_id"] = session_id
        
        logger.info(f"[CHATBOT_HANDLER] Response generated successfully. Fallback: {result.get('is_fallback', False)}")
        
        return result
        
    except ImportError as e:
        error_msg = f"Import error - run_ai.py not found or cannot be imported: {str(e)}"
        logger.error(f"[CHATBOT_HANDLER ERROR] {error_msg}")
        logger.error(f"[CHATBOT_HANDLER ERROR] Traceback: {traceback.format_exc()}")
        
        return {
            "success": False,
            "error_type": "CHATBOT_SERVICE_UNAVAILABLE",
            "message": (
                "The chatbot service is temporarily unavailable. "
                "The AI assistant module cannot be loaded. "
                "Please contact the system administrator."
            ),
            "answer": None,
            "session_id": session_id,
            "is_fallback": False,
            "used_context": [],
            "confidence_score": 0.0
        }
        
    except Exception as e:
        # Catch-all for any other errors
        error_msg = str(e)
        logger.error(f"[CHATBOT_HANDLER ERROR] {error_msg}")
        logger.error(f"[CHATBOT_HANDLER ERROR] Traceback: {traceback.format_exc()}")
        
        # Determine error type based on exception
        error_type = "CHATBOT_SERVICE_UNAVAILABLE"
        if "vector store" in error_msg.lower() or "vector_store" in error_msg.lower():
            error_type = "KNOWLEDGE_BASE_ERROR"
        elif "ollama" in error_msg.lower() or "model" in error_msg.lower():
            error_type = "LLM_ERROR"
        elif "embed" in error_msg.lower() or "embedding" in error_msg.lower():
            error_type = "EMBEDDING_ERROR"
        
        return {
            "success": False,
            "error_type": error_type,
            "message": (
                "The chatbot service is temporarily unavailable. "
                "Please try again later or contact your coordinator."
            ),
            "answer": None,
            "session_id": session_id,
            "is_fallback": False,
            "used_context": [],
            "confidence_score": 0.0
        }


# Backward compatibility: function that returns string (for existing code)
def chatbot_response_string(user_message: str, session_id: Optional[str] = None) -> str:
    """
    Legacy wrapper that returns a plain string response (backward compatibility).
    
    Args:
        user_message: User's input message
        session_id: Optional session ID
    
    Returns:
        Plain string response (answer or error message)
    """
    result = chatbot_response(user_message, session_id)
    
    if result.get("success") and result.get("answer"):
        return result["answer"]
    else:
        # Return error message as string for backward compatibility
        return result.get("message", "An error occurred while processing your message.")


def get_rag_context(user_message: str) -> str:
    """
    Retrieve relevant RAG context snippets for a user message.
    Used by the true Ollama streaming endpoint in server.py.
    Returns a string with the top relevant knowledge snippets.
    """
    try:
        from run_ai import retrieve_context
        snippets = retrieve_context(user_message, top_k=3)
        if snippets:
            return "\n---\n".join(snippets)
        return "No specific context found. Answer based on general OJT knowledge."
    except Exception:
        # Fallback: no RAG context, Gemma will answer from general knowledge
        return "Answer based on general JRMSU OJT guidelines and standard procedures."
