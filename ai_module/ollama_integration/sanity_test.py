import sys
import os
import json

# Add current directory to path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

try:
    from insight_engine import MODELS_LOADED, predict_performance, FEATURE_NAMES
    print(f"MODELS_LOADED: {MODELS_LOADED}")
    print(f"FEATURE_NAMES: {FEATURE_NAMES}")
    
    if MODELS_LOADED:
        # Mock features
        test_features = {f: 0.5 for f in FEATURE_NAMES}
        result = predict_performance(test_features)
        print(f"Test prediction successful: {result['success']}")
        print(f"Risk level: {result['risk_level']}")
    else:
        print("Models failed to load!")
        
except Exception as e:
    import traceback
    print(f"Error: {e}")
    traceback.print_exc()
