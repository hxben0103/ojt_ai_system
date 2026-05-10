import logging
import numpy as np

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Official OJT Competencies from seed_competencies.sql
COMPETENCIES = [
    "Software Development",
    "Machine Learning Engineering",
    "IT-Related Research",
    "User Experience / UI Design",
    "Information Security Analysis",
    "Networking",
    "Technical Support",
    "Data Analysis",
    "Customer Service",
    "Data Entry and Management",
    "Office Work"
]

# Fix #10: Pre-compute competency embeddings at startup using the already-loaded
# SentenceTransformer model. This replaces a full LLM call (2-5 seconds) with a
# simple cosine similarity lookup (~5ms).
_COMPETENCY_EMBEDDINGS = None

def _get_competency_embeddings():
    """Lazy-load competency embeddings using the existing SentenceTransformer model."""
    global _COMPETENCY_EMBEDDINGS
    if _COMPETENCY_EMBEDDINGS is None:
        try:
            from rag.embedder import embed_text
            _COMPETENCY_EMBEDDINGS = np.array(embed_text(COMPETENCIES), dtype=np.float32)
            # Pre-normalize for fast cosine similarity
            norms = np.linalg.norm(_COMPETENCY_EMBEDDINGS, axis=1, keepdims=True) + 1e-10
            _COMPETENCY_EMBEDDINGS = _COMPETENCY_EMBEDDINGS / norms
            logger.info(f"[COMPETENCY_HANDLER] Pre-computed embeddings for {len(COMPETENCIES)} competencies")
        except Exception as e:
            logger.warning(f"[COMPETENCY_HANDLER] Could not pre-compute embeddings: {e}")
            _COMPETENCY_EMBEDDINGS = None
    return _COMPETENCY_EMBEDDINGS


def suggest_competency(task_description: str) -> str:
    """
    Suggest a primary competency from the official list based on a task description.

    Uses semantic similarity via SentenceTransformer embeddings (~5ms) instead of
    a full LLM call (~3000ms). Falls back to keyword matching if embeddings fail.

    Args:
        task_description: The description of the task performed by the student.

    Returns:
        The title of the most fitting competency.
    """
    if not task_description or len(task_description.strip()) < 5:
        return "Office Work"  # Default fallback

    # Try embeddings-based matching first (fast path: ~5ms)
    comp_embs = _get_competency_embeddings()
    if comp_embs is not None:
        try:
            from rag.embedder import embed_text
            task_emb = np.array(embed_text(task_description)[0], dtype=np.float32)
            task_norm = np.linalg.norm(task_emb) + 1e-10
            task_normed = task_emb / task_norm

            # Single matrix-vector multiply for all similarities
            similarities = comp_embs @ task_normed
            best_idx = int(np.argmax(similarities))
            best_score = float(similarities[best_idx])

            logger.info(f"[COMPETENCY_HANDLER] Embedding match: {COMPETENCIES[best_idx]} (score={best_score:.3f})")

            # Only accept if similarity is reasonable (>0.2)
            if best_score > 0.2:
                return COMPETENCIES[best_idx]
        except Exception as e:
            logger.warning(f"[COMPETENCY_HANDLER] Embedding match failed: {e}")

    # Keyword fallback (instant)
    task_lower = task_description.lower()
    if "code" in task_lower or "app" in task_lower or "program" in task_lower or "develop" in task_lower:
        return "Software Development"
    if "ui" in task_lower or "design" in task_lower or "figma" in task_lower:
        return "User Experience / UI Design"
    if "network" in task_lower or "router" in task_lower or "server" in task_lower:
        return "Networking"
    if "ml" in task_lower or "machine learning" in task_lower or "model" in task_lower:
        return "Machine Learning Engineering"
    if "research" in task_lower or "study" in task_lower:
        return "IT-Related Research"
    if "security" in task_lower or "firewall" in task_lower:
        return "Information Security Analysis"
    if "support" in task_lower or "troubleshoot" in task_lower or "fix" in task_lower:
        return "Technical Support"
    if "analyze" in task_lower or "analysis" in task_lower or "report" in task_lower:
        return "Data Analysis"
    if "customer" in task_lower or "client" in task_lower:
        return "Customer Service"
    if "excel" in task_lower or "data" in task_lower or "entry" in task_lower or "encode" in task_lower:
        return "Data Entry and Management"

    return "Office Work"  # Global fallback


if __name__ == "__main__":
    # Test
    test_desc = "Developed a new feature for the mobile app using Flutter and integrated it with the backend API."
    print(f"Task: {test_desc}")
    print(f"Suggestion: {suggest_competency(test_desc)}")

    test_desc = "Cleaned the office and organized the files."
    print(f"Task: {test_desc}")
    print(f"Suggestion: {suggest_competency(test_desc)}")
