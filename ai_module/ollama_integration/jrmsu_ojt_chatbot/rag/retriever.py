# rag/retriever.py

import os
import json
import numpy as np

# Path to the vector store living inside rag/
BASE_DIR = os.path.dirname(__file__)
VECTOR_FILE = os.path.join(BASE_DIR, "vector_store.json")

# In-memory cache — loaded once, reused for all queries
_STORE = None


def load_vector_store():
    """Load vector_store.json from the rag folder (cached after first load)."""
    global _STORE
    if _STORE is not None:
        return _STORE
    if not os.path.exists(VECTOR_FILE):
        raise FileNotFoundError(f"Vector store not found: {VECTOR_FILE}")
    with open(VECTOR_FILE, "r", encoding="utf-8") as f:
        _STORE = json.load(f)
    return _STORE


def cosine_similarity(a, b):
    """Compute cosine similarity between two vectors."""
    a = np.array(a, dtype=float)
    b = np.array(b, dtype=float)
    denom = (np.linalg.norm(a) * np.linalg.norm(b)) + 1e-10
    return float(np.dot(a, b) / denom)


def retrieve_relevant_chunks(query_embedding, top_k=3):
    """
    Retrieve top_k most similar chunks to the query embedding.

    Returns:
        list[(score: float, chunk_text: str)]
    """
    store = load_vector_store()
    embeddings = store["embeddings"]
    chunks = store["chunks"]

    scored = []
    for emb, chunk in zip(embeddings, chunks):
        score = cosine_similarity(query_embedding, emb)
        scored.append((score, chunk))

    scored.sort(key=lambda x: x[0], reverse=True)
    return scored[:top_k]
