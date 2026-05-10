import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from chatbot_handler import _is_ojt_related, OJT_TOPIC_KEYWORDS

tests = [
    "what is cellphone",
    "tell me a joke",
    "weather today",
    "who is the president",
    "how to cook adobo",
    "what is love",
    "my attendance",
    "what is my grade",
    "show me students at risk",
    "how am i doing",
    "ojt requirements",
]

print(f"Keywords count: {len(OJT_TOPIC_KEYWORDS)}")
print()
for q in tests:
    result = "ALLOW" if _is_ojt_related(q) else "BLOCK"
    print(f"  {q:40s} -> {result}")
