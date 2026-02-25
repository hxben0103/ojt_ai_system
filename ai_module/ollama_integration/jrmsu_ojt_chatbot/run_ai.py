import os
import textwrap
import ollama
import logging
import traceback
import re
from typing import Dict, List, Optional, Tuple, Any

from rag.embedder import embed_text
from rag.retriever import retrieve_relevant_chunks

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Paths
BASE_KNOWLEDGE_DIR = os.path.join("data", "jrmsu_knowledge")

# Your Ollama model name
MODEL_NAME = "gemma2:2b"      # or "jrmsu-ojt-assistant" if you prefer
SIMILARITY_THRESHOLD = 0.25   # tuned so short queries like "dtr guidelines" still match
LOW_CONFIDENCE_THRESHOLD = 0.35  # Below this, we consider confidence low
DEBUG = True                  # set True to see retrieved chunks in console

APOLOGY = "I'm sorry, I don't have information about that based on JRMSU's knowledge base."
FALLBACK_MESSAGE = (
    "I'm not fully sure about that based on the available OJT documents. "
    "Please consult your OJT coordinator for confirmation."
)

# Maximum conversation history turns to include in prompt
MAX_CONTEXT_TURNS = 5


# ------------------------------------------------------------
# Utilities for formatting and cleaning
# ------------------------------------------------------------
def clean_llm_output(text: str) -> str:
    """
    Remove meta references such as:
    - 'provided knowledge text'
    - 'the document'
    - 'the file'
    so answers sound independent and not like they came from a file.
    """
    blocklist = [
        "provided knowledge",
        "knowledge text",
        "the document",
        "the file",
        "this text",
        "in the text",
        "in the document",
        "in the file",
        "section",
        "appendix",
        "provided text",
    ]

    lowered = text.lower()
    for word in blocklist:
        if word in lowered:
            sentences = text.split(".")
            sentences = [s for s in sentences if word not in s.lower()]
            text = ". ".join(sentences).strip()

    return text.strip()


def format_response(text: str, width: int = 95) -> str:
    """
    Clean response into a single flowing paragraph:
    - remove markdown symbols
    - collapse whitespace
    - wrap for terminal display
    """
    remove_list = ["**", "*", "-", "•", "–", "#", "`", "_"]

    for item in remove_list:
        text = text.replace(item, "")

    text = " ".join(text.split())  # collapse multiple spaces/newlines
    return textwrap.fill(text, width=width)


# ------------------------------------------------------------
# HARD-CODED EXACT ANSWERS for official JRMSU statements
# ------------------------------------------------------------
def load_text_file(filename: str) -> str | None:
    """
    Load a .txt file from data/jrmsu_knowledge.
    Returns None if file not found.
    """
    path = os.path.join(BASE_KNOWLEDGE_DIR, filename)
    abs_path = os.path.abspath(path)
    logger.debug(f"[LOAD_TEXT_FILE] Looking for: {filename}")
    logger.debug(f"[LOAD_TEXT_FILE] Full path: {abs_path}")
    logger.debug(f"[LOAD_TEXT_FILE] Path exists: {os.path.exists(path)}")
    if not os.path.exists(path):
        logger.warning(f"[LOAD_TEXT_FILE] File not found: {path}")
        return None
    try:
        with open(path, "r", encoding="utf-8") as f:
            content = f.read().strip()
            logger.debug(f"[LOAD_TEXT_FILE] Successfully loaded {len(content)} characters")
            return content
    except Exception as e:
        logger.error(f"[LOAD_TEXT_FILE] Error reading file {filename}: {e}")
        return None


def try_exact_university_answer(user_query: str) -> str | None:
    """
    If the question clearly refers to official JRMSU information,
    return the exact text from the appropriate file WITHOUT RAG/LLM.

    This is for:
    - vision
    - mission
    - goals
    - core values
    - history
    - university profile
    """
    q = user_query.lower()

    # Mission
    if "mission" in q and ("jrmsu" in q or "university" in q):
        text = load_text_file("jrmsu_mission.txt")
        if text:
            logger.info(f"[EXACT_ANSWER] Found mission file: {len(text)} chars")
            return text

    # Vision
    if "vision" in q and ("jrmsu" in q or "university" in q):
        text = load_text_file("jrmsu_vision.txt")
        if text:
            logger.info(f"[EXACT_ANSWER] Found vision file: {len(text)} chars")
            return text

    # Goals
    if "goal" in q or "goals" in q:
        text = load_text_file("jrmsu_goals.txt")
        if text:
            logger.info(f"[EXACT_ANSWER] Found goals file: {len(text)} chars")
            return text

    # Core values / values
    if "core values" in q or ("values" in q and "jrmsu" in q):
        text = load_text_file("jrmsu_core_values.txt")
        if text:
            logger.info(f"[EXACT_ANSWER] Found core values file: {len(text)} chars")
            return text

    # History
    if "history" in q and ("jrmsu" in q or "university" in q):
        text = load_text_file("history.txt")
        if text:
            logger.info(f"[EXACT_ANSWER] Found history file: {len(text)} chars")
            return text

    # University profile
    if "profile" in q or "university profile" in q:
        text = load_text_file("university_profile.txt")
        if text:
            logger.info(f"[EXACT_ANSWER] Found profile file: {len(text)} chars")
            return text

    return None


# ------------------------------------------------------------
# Fallback heuristic: exact text if retrieved chunk is official
# ------------------------------------------------------------
def should_use_exact_text(chunk: str) -> bool:
    """
    Backup heuristic in case we didn't match via try_exact_university_answer
    but the retrieved chunk is clearly an official JRMSU block.
    """
    keywords = [
        "vision",
        "mission",
        "core values",
        "goals",
        "university profile",
        "profile",
        "history",
        "jrmsu",
        "jose rizal memorial state university",
    ]

    if len(chunk) < 400:  # short official text
        lowered = chunk.lower()
        for word in keywords:
            if word in lowered:
                return True

    return False


# ------------------------------------------------------------
# Prompt building with conversation context
# ------------------------------------------------------------
def build_prompt_with_context(
    user_query: str,
    context_text: str,
    conversation_history: Optional[List[Dict[str, str]]] = None
) -> str:
    """
    Build the prompt for the LLM, including conversation context if available.
    
    Args:
        user_query: Current user question
        context_text: Retrieved knowledge base chunks
        conversation_history: Optional list of previous messages (from ConversationContext)
    
    Returns:
        Formatted prompt string
    """
    # Build conversation history section if available
    history_section = ""
    if conversation_history and len(conversation_history) > 0:
        history_lines = []
        for msg in conversation_history:
            role_label = "User" if msg.get("role") == "user" else "Assistant"
            content = msg.get("content", "")
            history_lines.append(f"{role_label}: {content}")
        
        history_section = f"""
Previous conversation:
{chr(10).join(history_lines)}

"""
    
    # Detect specific question types for targeted extraction
    query_lower = user_query.lower()
    is_specific_question = False
    extraction_instruction = ""
    
    if "president" in query_lower and "university" in query_lower:
        is_specific_question = True
        extraction_instruction = "IMPORTANT: Extract ONLY the name of the University President. Do NOT list other officials. Answer with just the name and title (e.g., 'Dr. Maria Rio Abdon Naguit, Ph.D., University President')."
    elif "learning competencies" in query_lower or "competencies" in query_lower:
        is_specific_question = True
        extraction_instruction = "IMPORTANT: Extract ONLY the relevant learning competencies information. Focus on the specific competencies mentioned, not the entire document structure."
    
    prompt = f"""
You are the JRMSU OJT Assistant. Use ONLY the JRMSU knowledge below to answer.

{history_section}JRMSU Knowledge:
{context_text}

Current question: {user_query}

{extraction_instruction if is_specific_question else ""}

Instructions:
- Respond with ONLY the specific information requested.
- If asked about a specific person (e.g., president), provide ONLY that person's name and title.
- If asked about specific information (e.g., competencies), provide ONLY the relevant details.
- DO NOT include entire lists or documents - extract only what was asked.
- Respond in one or two direct paragraphs only.
- DO NOT mention documents, files, chapters, sections, or sources.
- DO NOT explain where the information came from.
- DO NOT add unsupported information.
- DO NOT use bullet points or numbering unless the question specifically asks for a list.
- Always answer in a clear, formal, academic tone.
- If the conversation history is provided, use it to understand context and provide relevant follow-up answers.
""".strip()
    
    return prompt


# ------------------------------------------------------------
# Confidence assessment
# ------------------------------------------------------------
def assess_confidence(scored_chunks: List[Tuple[float, str]]) -> Tuple[bool, float]:
    """
    Assess confidence in the retrieved chunks.
    
    Args:
        scored_chunks: List of (similarity_score, chunk_text) tuples
    
    Returns:
        Tuple of (is_confident: bool, best_score: float)
        - is_confident: True if we have high confidence in the answer
        - best_score: The highest similarity score
    """
    if not scored_chunks:
        return False, 0.0
    
    best_score, _ = scored_chunks[0]
    
    # High confidence if best score is above threshold
    is_confident = best_score >= LOW_CONFIDENCE_THRESHOLD
    
    return is_confident, best_score


# ------------------------------------------------------------
# Main RAG + logic with enhanced error handling and context
# ------------------------------------------------------------
def generate_response(
    user_query: str,
    conversation_history: Optional[List[Dict[str, str]]] = None
) -> Dict[str, Any]:
    """
    Main answer pipeline with conversation context support.
    
    Args:
        user_query: User's question
        conversation_history: Optional list of previous messages (from ConversationContext)
    
    Returns:
        Dictionary with structured response:
        {
            "success": bool,
            "answer": str,
            "is_fallback": bool,
            "confidence_score": float,
            "used_context": List[str],  # List of retrieved chunk snippets
            "error_type": str | None,
            "message": str | None
        }
        
        On error, returns:
        {
            "success": False,
            "error_type": "CHATBOT_SERVICE_UNAVAILABLE" | "EMBEDDING_ERROR" | "RETRIEVAL_ERROR" | "LLM_ERROR",
            "message": "Human-readable error message",
            "answer": None,
            "is_fallback": False
        }
    """
    logger.info(f"[GENERATE_RESPONSE] Processing query: {user_query[:100]}...")
    
    # 0) FIRST: try direct exact answer for official university info
    logger.debug("[GENERATE_RESPONSE] Checking for exact answer...")
    try:
        exact = try_exact_university_answer(user_query)
        if exact:
            logger.info(f"[GENERATE_RESPONSE] Found exact answer from knowledge base ({len(exact)} chars)")
            return {
                "success": True,
                "answer": format_response(exact),
                "is_fallback": False,
                "confidence_score": 1.0,  # Exact answers are always high confidence
                "used_context": [exact[:200] + "..."],
                "error_type": None,
                "message": None
            }
    except Exception as e:
        logger.warning(f"[GENERATE_RESPONSE] Error in exact answer lookup: {e}")
        # Continue to RAG pipeline

    # 1) Embed question for RAG
    logger.debug("[GENERATE_RESPONSE] Embedding query...")
    try:
        query_embedding = embed_text(user_query)[0]
        logger.debug(f"[GENERATE_RESPONSE] Query embedded successfully (dimension: {len(query_embedding)})")
    except Exception as e:
        error_msg = f"Error embedding query: {str(e)}"
        logger.error(f"[GENERATE_RESPONSE] {error_msg}")
        logger.error(f"[GENERATE_RESPONSE] Traceback: {traceback.format_exc()}")
        return {
            "success": False,
            "error_type": "EMBEDDING_ERROR",
            "message": "Unable to process your question. The embedding service is unavailable.",
            "answer": None,
            "is_fallback": False,
            "confidence_score": 0.0,
            "used_context": []
        }

    # 2) Retrieve chunks (returns list of (score, chunk))
    logger.debug("[GENERATE_RESPONSE] Retrieving relevant chunks...")
    try:
        scored_chunks = retrieve_relevant_chunks(query_embedding, top_k=3)
        logger.info(f"[GENERATE_RESPONSE] Retrieved {len(scored_chunks)} chunks")
    except FileNotFoundError as e:
        error_msg = f"Vector store not found: {str(e)}"
        logger.error(f"[GENERATE_RESPONSE] {error_msg}")
        return {
            "success": False,
            "error_type": "RETRIEVAL_ERROR",
            "message": "The knowledge base vector store is missing. Please contact the administrator.",
            "answer": None,
            "is_fallback": False,
            "confidence_score": 0.0,
            "used_context": []
        }
    except Exception as e:
        error_msg = f"Error retrieving chunks: {str(e)}"
        logger.error(f"[GENERATE_RESPONSE] {error_msg}")
        logger.error(f"[GENERATE_RESPONSE] Traceback: {traceback.format_exc()}")
        return {
            "success": False,
            "error_type": "RETRIEVAL_ERROR",
            "message": "Unable to retrieve information from the knowledge base.",
            "answer": None,
            "is_fallback": False,
            "confidence_score": 0.0,
            "used_context": []
        }
    
    # Check if we have any chunks
    if not scored_chunks:
        logger.warning("[GENERATE_RESPONSE] No chunks retrieved - returning fallback")
        return {
            "success": True,
            "answer": FALLBACK_MESSAGE,
            "is_fallback": True,
            "confidence_score": 0.0,
            "used_context": [],
            "error_type": None,
            "message": None
        }

    best_score, best_chunk = scored_chunks[0]
    logger.info(f"[GENERATE_RESPONSE] Best similarity score: {best_score:.3f}")
    logger.debug(f"[GENERATE_RESPONSE] Best chunk preview: {best_chunk[:200].replace(chr(10), ' ')}...")
    
    if DEBUG:
        all_scores = [f'{s:.3f}' for s, _ in scored_chunks]
        logger.debug(f"[GENERATE_RESPONSE] All scores: {all_scores}")

    # 3) Assess confidence
    is_confident, confidence_score = assess_confidence(scored_chunks)
    
    # If similarity too low -> return fallback
    if best_score < SIMILARITY_THRESHOLD:
        logger.info(f"[GENERATE_RESPONSE] Score {best_score:.3f} below threshold {SIMILARITY_THRESHOLD} - returning fallback")
        return {
            "success": True,
            "answer": FALLBACK_MESSAGE,
            "is_fallback": True,
            "confidence_score": best_score,
            "used_context": [chunk[:200] + "..." for _, chunk in scored_chunks[:2]],
            "error_type": None,
            "message": None
        }

    # 4) If confidence is low but above threshold, still mark as fallback
    if not is_confident:
        logger.info(f"[GENERATE_RESPONSE] Low confidence ({best_score:.3f}) but above threshold - proceeding with warning")

    # 5) If this looks like official JRMSU info (vision, mission, profile...) → return EXACT TEXT
    if should_use_exact_text(best_chunk):
        logger.info("[GENERATE_RESPONSE] Using exact text from retrieved chunk")
        return {
            "success": True,
            "answer": format_response(best_chunk),
            "is_fallback": False,
            "confidence_score": best_score,
            "used_context": [best_chunk[:200] + "..."],
            "error_type": None,
            "message": None
        }

    # 6) Otherwise, build context for LLM (for OJT procedures, docs, etc.)
    logger.debug("[GENERATE_RESPONSE] Building context for LLM from retrieved chunks...")
    context_text = "\n\n".join(chunk for _, chunk in scored_chunks)
    logger.debug(f"[GENERATE_RESPONSE] Context length: {len(context_text)} characters")
    
    # Build prompt with conversation context
    prompt = build_prompt_with_context(user_query, context_text, conversation_history)

    # 7) LLM call with robust error handling
    logger.info(f"[GENERATE_RESPONSE] Calling Ollama model: {MODEL_NAME}")
    logger.debug(f"[GENERATE_RESPONSE] Prompt length: {len(prompt)} characters")
    
    try:
        # Build system message with extraction instructions if needed
        query_lower = user_query.lower()
        system_content = (
            "You are a formal academic assistant for JRMSU. "
            "You must answer ONLY with clean, direct information. "
            "Never reference documents, files, chapters, or sources. "
            "Use conversation history to provide context-aware answers when available."
        )
        
        # Add specific extraction instructions
        if "president" in query_lower and "university" in query_lower:
            system_content += (
                " IMPORTANT: If asked about the university president, provide ONLY the president's name and title. "
                "Do NOT list other officials or administrators."
            )
        elif "learning competencies" in query_lower or ("competencies" in query_lower and "learning" in query_lower):
            system_content += (
                " IMPORTANT: If asked about learning competencies, provide ONLY the specific competency information requested. "
                "Do NOT include the entire document structure or all competencies."
            )
        
        response = ollama.chat(
            model=MODEL_NAME,
            messages=[
                {
                    "role": "system",
                    "content": system_content,
                },
                {"role": "user", "content": prompt},
            ],
            options={
                "temperature": 0.2,
                "top_p": 0.9,
                "num_ctx": 2048,  # Reduced from 4096 for faster processing
                "num_predict": 500,  # Limit response length for faster generation
            },
        )
        raw_answer = response["message"]["content"].strip()
        logger.info(f"[GENERATE_RESPONSE] LLM response received: {len(raw_answer)} characters")
        
    except ConnectionError as e:
        error_msg = f"Cannot connect to Ollama: {str(e)}"
        logger.error(f"[GENERATE_RESPONSE] {error_msg}")
        logger.error(f"[GENERATE_RESPONSE] Traceback: {traceback.format_exc()}")
        # Fallback: return best chunk directly if LLM fails
        logger.info("[GENERATE_RESPONSE] LLM unavailable, falling back to direct chunk response")
        return {
            "success": True,
            "answer": format_response(best_chunk),
            "is_fallback": True,  # Mark as fallback since LLM unavailable
            "confidence_score": best_score,
            "used_context": [chunk[:200] + "..." for _, chunk in scored_chunks[:2]],
            "error_type": None,
            "message": "LLM service temporarily unavailable, showing retrieved information"
        }
    
    except TimeoutError as e:
        error_msg = f"Ollama request timed out: {str(e)}"
        logger.error(f"[GENERATE_RESPONSE] {error_msg}")
        logger.error(f"[GENERATE_RESPONSE] Traceback: {traceback.format_exc()}")
        return {
            "success": False,
            "error_type": "LLM_ERROR",
            "message": "The AI model took too long to respond. Please try again.",
            "answer": None,
            "is_fallback": False,
            "confidence_score": 0.0,
            "used_context": [chunk[:200] + "..." for _, chunk in scored_chunks[:2]]
        }
    
    except Exception as e:
        error_msg = f"Error calling Ollama: {str(e)}"
        logger.error(f"[GENERATE_RESPONSE] {error_msg}")
        logger.error(f"[GENERATE_RESPONSE] Traceback: {traceback.format_exc()}")
        # Fallback: return best chunk directly if LLM fails
        logger.info("[GENERATE_RESPONSE] LLM error, falling back to direct chunk response")
        return {
            "success": True,
            "answer": format_response(best_chunk),
            "is_fallback": True,  # Mark as fallback since LLM failed
            "confidence_score": best_score,
            "used_context": [chunk[:200] + "..." for _, chunk in scored_chunks[:2]],
            "error_type": None,
            "message": "LLM processing error, showing retrieved information"
        }

    # 8) Remove internal apology if model includes it
    if APOLOGY in raw_answer:
        raw_answer = raw_answer.replace(APOLOGY, "").strip()

    # 9) Post-process to extract specific information if needed
    query_lower = user_query.lower()
    
    # Extract only university president if asked
    if "president" in query_lower and "university" in query_lower:
        # Try to extract just the president's name from the response
        # Look for patterns like "Dr. Maria Rio Abdon Naguit" or "University President: ..."
        president_patterns = [
            r"Dr\.\s+Maria\s+Rio\s+Abdon\s+Naguit[^.\n]*",
            r"DR\.\s+MARIA\s+RIO\s+ABDON\s+NAGUIT[^.\n]*",
            r"University\s+President[:\s]+Dr\.\s+Maria\s+Rio\s+Abdon\s+Naguit[^.\n]*",
        ]
        for pattern in president_patterns:
            match = re.search(pattern, raw_answer, re.IGNORECASE)
            if match:
                extracted = match.group(0).strip()
                # Clean up the extracted text
                extracted = re.sub(r'\s+', ' ', extracted)
                # Ensure it includes the title
                if "University President" not in extracted and "Ph.D" not in extracted:
                    extracted = "Dr. Maria Rio Abdon Naguit, Ph.D., University President"
                elif "University President" not in extracted:
                    extracted = f"{extracted}, University President"
                raw_answer = extracted
                logger.info(f"[GENERATE_RESPONSE] Extracted president info: {extracted[:100]}")
                break
    
    # Extract only relevant competencies if asked
    if "learning competencies" in query_lower or ("competencies" in query_lower and "learning" in query_lower):
        # Try to extract just the competency information, not the entire document
        # Look for competency-related sentences
        lines = raw_answer.split('.')
        competency_lines = []
        for line in lines:
            line_lower = line.lower()
            if any(keyword in line_lower for keyword in ["competency", "skill", "ability", "proficiency", "capability"]):
                competency_lines.append(line.strip())
        
        if competency_lines:
            # Take first 3-5 relevant sentences
            raw_answer = '. '.join(competency_lines[:5]).strip()
            if raw_answer and not raw_answer.endswith('.'):
                raw_answer += '.'
    
    # 10) Remove meta-reference sentences (chapter, document, etc.)
    cleaned = clean_llm_output(raw_answer)

    # 11) Format as single paragraph
    cleaned = format_response(cleaned)

    if not cleaned:
        logger.warning("[GENERATE_RESPONSE] LLM returned empty response, using fallback")
        return {
            "success": True,
            "answer": FALLBACK_MESSAGE,
            "is_fallback": True,
            "confidence_score": best_score,
            "used_context": [chunk[:200] + "..." for _, chunk in scored_chunks[:2]],
            "error_type": None,
            "message": None
        }

    # Return successful response
    return {
        "success": True,
        "answer": cleaned,
        "is_fallback": not is_confident,  # Mark as fallback if confidence was low
        "confidence_score": best_score,
        "used_context": [chunk[:200] + "..." for _, chunk in scored_chunks[:2]],
        "error_type": None,
        "message": None
    }


# ------------------------------------------------------------
# Chat loop (for CLI testing)
# ------------------------------------------------------------
def chat():
    """Simple CLI chat interface for testing."""
    print("JRMSU OJT Assistant")
    print("Type 'exit' to quit.\n")

    greeting = (
        "Hello. I am the JRMSU OJT Assistant. I can provide formal information about JRMSU, "
        "the OJT program, requirements, procedures, and related university guidelines."
    )
    print("\nJRMSU OJT Assistant:", format_response(greeting))

    while True:
        user_input = input("\nYou: ").strip()
        if user_input.lower() in ["exit", "quit"]:
            print("👋 Goodbye!")
            break

        result = generate_response(user_input)
        if result["success"]:
            print("\nJRMSU OJT Assistant:", result["answer"])
            if result.get("is_fallback"):
                print("  [Note: This is a low-confidence answer]")
        else:
            print(f"\nError: {result.get('message', 'Unknown error')}")


if __name__ == "__main__":
    chat()
