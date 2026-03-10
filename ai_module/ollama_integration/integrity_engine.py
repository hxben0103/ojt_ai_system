import os
import pickle
import numpy as np
import logging

logger = logging.getLogger(__name__)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_DIR = os.path.join(BASE_DIR, "../models")

# Load model once
INTEGRITY_MODEL = None
try:
    with open(os.path.join(MODEL_DIR, "integrity_model.pkl"), 'rb') as f:
        INTEGRITY_MODEL = pickle.load(f)
    logger.info("✅ Integrity model loaded successfully.")
except Exception as e:
    logger.error(f"❌ Failed to load integrity model: {e}")

def assess_integrity_score(inside_geofence: bool, distance_m: float, accuracy_m: float, trust_flags: str, has_photo: bool, recent_flags_count: int) -> dict:
    """
    Evaluates check-in behavior using hybrid rules + Isolation Forest.
    Returns the integrity block for the unified JSON schema.
    """
    score = 100
    flags = []
    
    # 1. Rule-based deductions
    if not inside_geofence:
        score -= 40
        flags.append("Check-in outside assigned OJT location")
        
    if trust_flags:
        flags_list = str(trust_flags).lower()
        if 'mock' in flags_list:
            score -= 60
            flags.append("Mock GPS pattern detected")
        if 'teleport' in flags_list:
            score -= 40
            flags.append("Teleport jump detected")
            
    if accuracy_m > 100:
        score -= 20
        flags.append("Low GPS accuracy (>100m)")
        
    if not has_photo:
        score -= 25
        flags.append("Photo evidence missing")
        
    if recent_flags_count > 0:
        penalty = min(recent_flags_count * 10, 30)
        score -= penalty
        flags.append(f"Repeated suspicious flags history (-{penalty} pts)")
        
    # 2. ML Anomaly Detection (Isolation Forest)
    if INTEGRITY_MODEL is not None:
        try:
            # Features: [distance_m, accuracy_m, has_photo_int]
            features = np.array([[float(distance_m), float(accuracy_m), 1 if has_photo else 0]])
            prediction = INTEGRITY_MODEL.predict(features)[0]
            
            if prediction == -1:
                # Model caught an anomaly not completely covered by rigid rules
                score -= 15
                if "Anomalous behavior pattern detected by AI" not in flags:
                    flags.append("Anomalous behavior pattern detected by AI")
        except Exception as e:
            logger.warning(f"Failed to run integrity ML model: {e}")

    # Clamp score
    score = max(0, min(100, score))
    
    # Determine severity
    severity = "low"
    if score < 50:
        severity = "high"
    elif score < 80:
        severity = "medium"
        
    return {
        "integrity_score": score,
        "flags": flags,
        "severity": severity,
        "explanation": flags if flags else ["Standard behavior pattern verified"]
    }
