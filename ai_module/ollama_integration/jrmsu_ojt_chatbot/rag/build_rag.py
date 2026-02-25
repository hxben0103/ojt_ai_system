# rag/build_rag.py

import os
import json
import re
from embedder import embed_text

BASE_DIR = os.path.dirname(os.path.dirname(__file__))
DATA_DIR = os.path.join(BASE_DIR, "data", "jrmsu_knowledge")
OUTPUT_FILE = os.path.join(os.path.dirname(__file__), "vector_store.json")


def clean_text(text: str) -> str:
    """Remove document references, chapter titles, and meta text."""
    text = re.sub(r"Chapter\s+\w+[\s:-]*", "", text, flags=re.IGNORECASE)
    text = re.sub(r"provided knowledge text", "", text, flags=re.IGNORECASE)
    text = re.sub(r"\bthis chapter\b", "", text, flags=re.IGNORECASE)
    text = re.sub(r"\bthe document\b", "", text, flags=re.IGNORECASE)
    text = re.sub(r"\bthe file\b", "", text, flags=re.IGNORECASE)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def load_all_text():
    chunks = []
    for filename in os.listdir(DATA_DIR):
        if filename.endswith(".txt"):
            path = os.path.join(DATA_DIR, filename)
            with open(path, "r", encoding="utf-8") as f:
                raw = f.read().strip()
                cleaned = clean_text(raw)
                if cleaned:
                    chunks.append(cleaned)
    return chunks


def build_vector_store():
    print("📌 Loading JRMSU knowledge files...")
    chunks = load_all_text()
    print(f"📌 Loaded {len(chunks)} cleaned chunks.")

    print("📌 Generating embeddings...")
    embeddings = embed_text(chunks)

    store = {
        "chunks": chunks,
        "embeddings": embeddings
    }

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(store, f, indent=2)

    print(f"✅ RAG vector store built successfully → {OUTPUT_FILE}")


if __name__ == "__main__":
    build_vector_store()
