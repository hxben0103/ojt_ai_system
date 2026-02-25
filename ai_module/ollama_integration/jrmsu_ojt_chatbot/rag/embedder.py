# rag/embedder.py

from sentence_transformers import SentenceTransformer
import os

# Load the embedding model once (cached after first load)
_model = None

def _get_model():
    """Lazy load the embedding model to avoid slow startup."""
    global _model
    if _model is None:
        print("[EMBEDDER] Loading SentenceTransformer model (first time only, this may take a moment)...")
        _model = SentenceTransformer("all-MiniLM-L6-v2")
        print("[EMBEDDER] Model loaded successfully")
    return _model


def embed_text(texts):
    """
    Embed a string or list of strings into numeric vectors.

    Args:
        texts: str or list[str]

    Returns:
        list[list[float]] of embeddings
    """
    if isinstance(texts, str):
        texts = [texts]

    model = _get_model()
    embeddings = model.encode(texts, convert_to_numpy=True, show_progress_bar=False)
    return embeddings.tolist()
