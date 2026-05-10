"""
Session-based conversation context manager for the JRMSU OJT chatbot.

This module maintains conversation history in memory, keyed by session_id.
It limits the history size to prevent unbounded growth and token overflow.
"""

import time
from typing import List, Dict, Optional, Tuple
from collections import deque
import logging

logger = logging.getLogger(__name__)

# Configuration
MAX_HISTORY_MESSAGES = 10  # Keep last 10 message pairs (user + bot = 20 messages total)
MAX_SESSION_AGE_SECONDS = 3600 * 24  # 24 hours - sessions expire after this


class ConversationMessage:
    """Represents a single message in the conversation."""
    
    def __init__(self, role: str, content: str, timestamp: float = None):
        """
        Args:
            role: 'user' or 'assistant'
            content: Message text
            timestamp: Unix timestamp (defaults to current time)
        """
        self.role = role
        self.content = content
        self.timestamp = timestamp or time.time()
    
    def to_dict(self) -> Dict[str, any]:
        """Convert to dictionary for JSON serialization."""
        return {
            "role": self.role,
            "content": self.content,
            "timestamp": self.timestamp
        }


class ConversationContext:
    """Manages conversation history for a single session."""
    
    def __init__(self, session_id: str):
        """
        Args:
            session_id: Unique identifier for this conversation session
        """
        self.session_id = session_id
        self.messages: deque = deque(maxlen=MAX_HISTORY_MESSAGES * 2)  # User + bot pairs
        self.created_at = time.time()
        self.last_activity = time.time()
    
    def add_user_message(self, content: str):
        """Add a user message to the conversation."""
        message = ConversationMessage("user", content)
        self.messages.append(message)
        self.last_activity = time.time()
        logger.debug(f"[Context] Added user message to session {self.session_id}")
    
    def add_assistant_message(self, content: str):
        """Add an assistant/bot message to the conversation."""
        message = ConversationMessage("assistant", content)
        self.messages.append(message)
        self.last_activity = time.time()
        logger.debug(f"[Context] Added assistant message to session {self.session_id}")
    
    def get_recent_history(self, max_turns: int = 5) -> List[Dict[str, str]]:
        """
        Get recent conversation history for prompt inclusion.
        
        Args:
            max_turns: Maximum number of conversation turns (user+assistant pairs) to include
        
        Returns:
            List of message dicts with 'role' and 'content' keys, suitable for LLM prompt
        """
        # Get last max_turns * 2 messages (each turn = user + assistant)
        recent = list(self.messages)[-max_turns * 2:]
        return [msg.to_dict() for msg in recent]
    
    def get_history_as_text(self, max_turns: int = 5) -> str:
        """
        Format conversation history as a text string for prompt inclusion.
        
        Args:
            max_turns: Maximum number of conversation turns to include
        
        Returns:
            Formatted string showing conversation history
        """
        history = self.get_recent_history(max_turns)
        if not history:
            return ""
        
        lines = []
        for msg in history:
            role_label = "User" if msg["role"] == "user" else "Assistant"
            lines.append(f"{role_label}: {msg['content']}")
        
        return "\n".join(lines)
    
    def is_expired(self) -> bool:
        """Check if this session has expired due to inactivity."""
        age = time.time() - self.last_activity
        return age > MAX_SESSION_AGE_SECONDS
    
    def clear(self):
        """Clear all conversation history (useful for testing or explicit reset)."""
        self.messages.clear()
        self.last_activity = time.time()
        logger.debug(f"[Context] Cleared conversation for session {self.session_id}")


class ContextManager:
    """
    Global context manager that stores conversation contexts for multiple sessions.
    
    This is a simple in-memory implementation. For production, consider using
    Redis or a database for persistence and scalability.
    """
    
    def __init__(self):
        """Initialize the context manager."""
        self.contexts: Dict[str, ConversationContext] = {}
        self._last_cleanup = time.time()
        logger.info("[ContextManager] Initialized conversation context manager")
    
    def get_or_create_context(self, session_id: str) -> ConversationContext:
        """
        Get existing context or create a new one for the given session_id.
        
        Args:
            session_id: Unique session identifier
        
        Returns:
            ConversationContext instance
        """
        # Fix #7: Time-based cleanup every 10 minutes instead of unreliable
        # modulo-100 trigger that missed most expired sessions.
        if time.time() - self._last_cleanup > 600:
            self._cleanup_expired_sessions()
            self._last_cleanup = time.time()
        
        if session_id not in self.contexts:
            self.contexts[session_id] = ConversationContext(session_id)
            logger.info(f"[ContextManager] Created new context for session: {session_id}")
        
        context = self.contexts[session_id]
        
        # Check if existing session expired
        if context.is_expired():
            logger.info(f"[ContextManager] Session {session_id} expired, creating new context")
            self.contexts[session_id] = ConversationContext(session_id)
            context = self.contexts[session_id]
        
        return context
    
    def get_context(self, session_id: str) -> Optional[ConversationContext]:
        """
        Get existing context without creating a new one.
        
        Args:
            session_id: Session identifier
        
        Returns:
            ConversationContext if exists, None otherwise
        """
        context = self.contexts.get(session_id)
        if context and context.is_expired():
            # Remove expired context
            del self.contexts[session_id]
            return None
        return context
    
    def delete_context(self, session_id: str):
        """Delete a conversation context (e.g., on explicit session end)."""
        if session_id in self.contexts:
            del self.contexts[session_id]
            logger.info(f"[ContextManager] Deleted context for session: {session_id}")
    
    def _cleanup_expired_sessions(self):
        """Remove all expired sessions to free memory."""
        expired_ids = [
            sid for sid, ctx in self.contexts.items()
            if ctx.is_expired()
        ]
        for sid in expired_ids:
            del self.contexts[sid]
        
        if expired_ids:
            logger.info(f"[ContextManager] Cleaned up {len(expired_ids)} expired sessions")
    
    def get_stats(self) -> Dict[str, any]:
        """Get statistics about active sessions (useful for monitoring)."""
        active_sessions = [ctx for ctx in self.contexts.values() if not ctx.is_expired()]
        return {
            "total_sessions": len(self.contexts),
            "active_sessions": len(active_sessions),
            "expired_sessions": len(self.contexts) - len(active_sessions)
        }


# Global instance - singleton pattern
_context_manager = ContextManager()


def get_context_manager() -> ContextManager:
    """Get the global context manager instance."""
    return _context_manager

