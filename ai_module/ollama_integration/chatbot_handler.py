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
        
        # Inject career and competency data if provided
        career_briefing = ""
        if student_data:
            try:
                career_briefing = generate_career_briefing(student_data)
            except Exception as ce:
                logger.error(f"[CHATBOT_HANDLER] Error generating career briefing: {ce}")
        
        text_for_llm = career_briefing + text if career_briefing else text
        
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
