# JRMSU OJT Chatbot Improvements

This document summarizes the improvements made to the RAG-based chatbot system.

## Summary of Changes

Three major improvements were implemented:
1. **Conversation context within a session**
2. **Fallbacks when no good answer is found**
3. **Failure handling when the LLM/RAG fails**

---

## 1. Conversation Context Support

### New Files Created

- **`chatbot_context.py`**: Session-based conversation context manager

### Key Features

- **Session Management**: Each user/client can send a `session_id` to maintain conversation history
- **History Limiting**: Conversation history is capped at 10 message pairs (20 messages total) to prevent token overflow
- **Automatic Expiration**: Sessions expire after 24 hours of inactivity
- **Memory Efficient**: Uses `deque` with maxlen for automatic history trimming

### How It Works

1. When a user sends a message with a `session_id`, the context manager retrieves or creates a conversation context
2. The user message is added to the context
3. Previous conversation history (last 5 turns) is included in the LLM prompt
4. The assistant response is added to the context for future reference

### Example Usage

```python
from chatbot_handler import chatbot_response

# First message
result1 = chatbot_response("What are the OJT requirements?", session_id="user123")
# result1["session_id"] = "user123"

# Follow-up message (remembers context)
result2 = chatbot_response("How many hours are required?", session_id="user123")
# The LLM will understand "How many hours" refers to OJT hours from previous question
```

### Code Structure

- `ConversationMessage`: Represents a single message (user/assistant)
- `ConversationContext`: Manages history for a single session
- `ContextManager`: Global manager for multiple sessions (singleton pattern)

---

## 2. Fallback Behavior Improvements

### Enhanced Confidence Assessment

- **Similarity Threshold**: `SIMILARITY_THRESHOLD = 0.25` (below this, no answer returned)
- **Low Confidence Threshold**: `LOW_CONFIDENCE_THRESHOLD = 0.35` (below this, marked as fallback)
- **Fallback Message**: Clear, honest message directing users to consult their coordinator

### Fallback Triggers

1. **No chunks retrieved**: Returns fallback message
2. **Similarity score too low**: Below `SIMILARITY_THRESHOLD` → returns fallback
3. **Low confidence**: Above threshold but below `LOW_CONFIDENCE_THRESHOLD` → proceeds but marks as fallback
4. **LLM unavailable**: Falls back to showing retrieved chunks directly

### Response Structure

All responses now include:
- `is_fallback`: Boolean flag indicating low-confidence answer
- `confidence_score`: Numeric score (0.0 to 1.0) indicating retrieval confidence
- `used_context`: List of retrieved document snippets used for the answer

### Example Fallback Response

```json
{
  "success": true,
  "answer": "I'm not fully sure about that based on the available OJT documents. Please consult your OJT coordinator for confirmation.",
  "is_fallback": true,
  "confidence_score": 0.28,
  "used_context": ["...retrieved snippet..."],
  "session_id": "user123"
}
```

---

## 3. Robust Error Handling

### Error Types

1. **EMBEDDING_ERROR**: Failed to embed user query
2. **RETRIEVAL_ERROR**: Failed to retrieve chunks from vector store
3. **LLM_ERROR**: Failed to call Ollama/LLM
4. **CHATBOT_SERVICE_UNAVAILABLE**: General service unavailable
5. **INVALID_INPUT**: Empty or invalid user message

### Error Handling Strategy

- **Try/Except Blocks**: All LLM and RAG calls are wrapped in try/except
- **Structured Error Responses**: Errors return consistent JSON structure
- **Graceful Degradation**: When LLM fails, falls back to showing retrieved chunks
- **Detailed Logging**: All errors are logged with stack traces for debugging

### Example Error Response

```json
{
  "success": false,
  "error_type": "LLM_ERROR",
  "message": "The AI model took too long to respond. Please try again.",
  "answer": null,
  "session_id": "user123",
  "is_fallback": false,
  "used_context": [],
  "confidence_score": 0.0
}
```

---

## 4. API Contract

### Updated Endpoint: `/chat` (POST)

#### Request Format

```json
{
  "message": "What are the OJT requirements?",
  "session_id": "user123"  // Optional
}
```

#### Success Response

```json
{
  "success": true,
  "answer": "To participate in the OJT program...",
  "is_fallback": false,
  "session_id": "user123",
  "used_context": ["...snippet 1...", "...snippet 2..."],
  "confidence_score": 0.85,
  "error_type": null,
  "message": null
}
```

#### Error Response

```json
{
  "success": false,
  "error_type": "CHATBOT_SERVICE_UNAVAILABLE",
  "message": "The chatbot service is temporarily unavailable...",
  "answer": null,
  "session_id": "user123",
  "is_fallback": false,
  "used_context": [],
  "confidence_score": 0.0
}
```

### HTTP Status Codes

- `200`: Successful response (even if `is_fallback: true`)
- `400`: Invalid input (empty message, etc.)
- `500`: Internal server error
- `503`: Service unavailable (LLM down, knowledge base missing, etc.)

---

## 5. Modified Files

### Core Files

1. **`jrmsu_ojt_chatbot/run_ai.py`**
   - Updated `generate_response()` to accept `conversation_history` parameter
   - Added `build_prompt_with_context()` function
   - Added `assess_confidence()` function
   - Enhanced error handling with structured responses
   - Returns dictionary instead of plain string

2. **`chatbot_handler.py`**
   - Integrated context manager
   - Updated to use new structured response format
   - Enhanced error handling and logging
   - Maintains backward compatibility with `chatbot_response_string()` function

3. **`server.py`**
   - Updated `/chat` endpoint to handle new API contract
   - Accepts optional `session_id` parameter
   - Returns structured JSON responses
   - Proper HTTP status code mapping

### New Files

1. **`chatbot_context.py`**
   - Complete session management system
   - Conversation history storage and retrieval
   - Session expiration and cleanup

2. **`jrmsu_ojt_chatbot/data/jrmsu_knowledge/KNOWLEDGE_BASE_COVERAGE.md`**
   - Documentation of knowledge base coverage
   - Identifies missing topics
   - Recommendations for additions

---

## 6. Backward Compatibility

### Legacy Support

The `chatbot_handler.py` module includes a backward-compatible function:

```python
def chatbot_response_string(user_message: str, session_id: Optional[str] = None) -> str:
    """Returns plain string (for existing code that expects strings)"""
```

### Migration Path

1. **Old code** (still works):
   ```python
   response = chatbot_response_string("What are requirements?")
   # Returns: "To participate in the OJT program..."
   ```

2. **New code** (recommended):
   ```python
   result = chatbot_response("What are requirements?", session_id="user123")
   # Returns: {"success": True, "answer": "...", "is_fallback": False, ...}
   ```

---

## 7. Configuration

### Context Manager Settings

In `chatbot_context.py`:
```python
MAX_HISTORY_MESSAGES = 10  # Last 10 message pairs (20 messages total)
MAX_SESSION_AGE_SECONDS = 3600 * 24  # 24 hours
```

### RAG Settings

In `run_ai.py`:
```python
SIMILARITY_THRESHOLD = 0.25  # Below this, return fallback
LOW_CONFIDENCE_THRESHOLD = 0.35  # Below this, mark as fallback
MAX_CONTEXT_TURNS = 5  # Conversation history turns to include
```

---

## 8. Testing Recommendations

### Test Scenarios

1. **Context Persistence**
   - Send multiple messages with same `session_id`
   - Verify that follow-up questions are answered in context

2. **Fallback Detection**
   - Ask questions about topics not in knowledge base
   - Verify `is_fallback: true` in response

3. **Error Handling**
   - Stop Ollama service and test error response
   - Remove vector store file and test error response
   - Test with empty/invalid input

4. **Session Expiration**
   - Create a session and wait 24+ hours
   - Verify new context is created (old one expired)

---

## 9. Frontend Integration

### Example Frontend Code (JavaScript/Flutter)

```javascript
// Store session ID in user's session/localStorage
let sessionId = localStorage.getItem('chatbot_session_id') || generateUUID();

// Send message with session ID
const response = await fetch('/chat', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    message: userMessage,
    session_id: sessionId
  })
});

const result = await response.json();

if (result.success) {
  if (result.is_fallback) {
    // Show warning: "This answer may not be complete. Consult your coordinator."
    showWarning(result.answer);
  } else {
    // Show normal response
    showMessage(result.answer);
  }
} else {
  // Show error
  showError(result.message);
}
```

---

## 10. Future Enhancements

### Recommended Improvements

1. **Persistent Storage**: Move context from memory to Redis/database for multi-server deployments
2. **Context Summarization**: Summarize old context when history gets long
3. **User Preferences**: Allow users to reset context or adjust history length
4. **Analytics**: Track fallback rates and common questions
5. **A/B Testing**: Test different similarity thresholds

---

## 11. Troubleshooting

### Common Issues

1. **"Session expired" messages**
   - Normal behavior after 24 hours of inactivity
   - Frontend should generate new session_id

2. **High fallback rate**
   - Check similarity threshold settings
   - Verify knowledge base coverage (see KNOWLEDGE_BASE_COVERAGE.md)
   - Consider rebuilding vector store

3. **Context not working**
   - Verify `session_id` is being sent consistently
   - Check that same `session_id` is used across requests

---

**Last Updated**: 2024-01-XX
**Version**: 2.0 (Enhanced with context, fallbacks, and error handling)

