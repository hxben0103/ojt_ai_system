# rag/retriever.py

import os
import json
import numpy as np

# Path to the vector store living inside rag/
BASE_DIR = os.path.dirname(__file__)
VECTOR_FILE = os.path.join(BASE_DIR, "vector_store.json")

# In-memory cache — loaded once, reused for all queries
_STORE = None
# Pre-computed normalised embedding matrix (built once after first load)
_EMB_MATRIX_NORMED = None


def load_vector_store():
    """Load vector_store.json from the rag folder (cached after first load)."""
    global _STORE, _EMB_MATRIX_NORMED
    if _STORE is not None:
        return _STORE
    if not os.path.exists(VECTOR_FILE):
        raise FileNotFoundError(f"Vector store not found: {VECTOR_FILE}")
    with open(VECTOR_FILE, "r", encoding="utf-8") as f:
        _STORE = json.load(f)

    # Pre-compute normalised embedding matrix once (vectorised cosine similarity)
    emb_matrix = np.array(_STORE["embeddings"], dtype=np.float32)
    norms = np.linalg.norm(emb_matrix, axis=1, keepdims=True) + 1e-10
    _EMB_MATRIX_NORMED = emb_matrix / norms

    return _STORE


def retrieve_relevant_chunks(query_embedding, top_k=3):
    """
    Retrieve top_k most similar chunks to the query embedding.

    Uses vectorised NumPy matrix multiplication instead of a Python loop
    for ~10-50x faster cosine similarity computation.

    Returns:
        list[(score: float, chunk_text: str)]
    """
    store = load_vector_store()
    chunks = store["chunks"]

    # Normalise query vector
    q = np.array(query_embedding, dtype=np.float32)
    q_norm = np.linalg.norm(q) + 1e-10
    q_normed = q / q_norm

    # Single matrix-vector multiply — replaces entire Python loop + per-pair
    # np.array construction.  O(n) dot products in one C-level call.
    scores = _EMB_MATRIX_NORMED @ q_normed  # shape: (n_chunks,)

    # Use argpartition for O(n) top-k selection instead of O(n log n) full sort
    if len(scores) <= top_k:
        top_idx = np.argsort(scores)[::-1]
    else:
        top_idx = np.argpartition(scores, -top_k)[-top_k:]
        top_idx = top_idx[np.argsort(scores[top_idx])[::-1]]

    return [(float(scores[i]), chunks[i]) for i in top_idx]
