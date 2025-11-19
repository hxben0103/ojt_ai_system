import os
import pickle
import numpy as np
from typing import Dict, Any

# =========================================================
# Directory Setup
# =========================================================
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_DIR = os.path.join(BASE_DIR, "../models")

# =========================================================
# Model Loading (Load once at module import)
# =========================================================
try:
    # Load individual models
    with open(os.path.join(MODEL_DIR, "logistic_regression.pkl"), 'rb') as f:
        LR_MODEL = pickle.load(f)
    
    with open(os.path.join(MODEL_DIR, "random_forest.pkl"), 'rb') as f:
        RF_MODEL = pickle.load(f)
    
    with open(os.path.join(MODEL_DIR, "naive_bayes.pkl"), 'rb') as f:
        NB_MODEL = pickle.load(f)
    
    # Load preprocessing artifacts
    with open(os.path.join(MODEL_DIR, "scaler.pkl"), 'rb') as f:
        SCALER = pickle.load(f)
    
    with open(os.path.join(MODEL_DIR, "label_encoder.pkl"), 'rb') as f:
        LABEL_ENCODER = pickle.load(f)
    
    with open(os.path.join(MODEL_DIR, "feature_names.pkl"), 'rb') as f:
        FEATURE_NAMES = pickle.load(f)
    
    MODELS_LOADED = True
    print(f"✅ Models loaded successfully. Features: {FEATURE_NAMES}")
except Exception as e:
    MODELS_LOADED = False
    print(f"⚠️ Warning: Failed to load models: {e}")
    LR_MODEL = None
    RF_MODEL = None
    NB_MODEL = None
    SCALER = None
    LABEL_ENCODER = None
    FEATURE_NAMES = None

# Ensemble weights (LR, RF, NB)
MODEL_WEIGHTS = np.array([0.4, 0.4, 0.2])


# =========================================================
# Feature Mapping from Snapshot
# =========================================================
def build_features_from_snapshot(snapshot: Dict[str, Any]) -> Dict[str, float]:
    """
    Convert daily student snapshot to model feature dictionary.
    
    Args:
        snapshot: Daily student state from backend, e.g.
            {
                "daily_progress_score": 82,
                "narrative_score": 85,
                "coord_eval_score": 88,
                "partner_eval_score": 90,
                "attendance_days_present": 18
            }
    
    Returns:
        Dictionary mapping feature names to numeric values
    """
    if not FEATURE_NAMES:
        raise ValueError("Feature names not loaded. Models may not be initialized.")
    
    # Map snapshot fields to feature names
    # Feature names from training:
    # ['Weekly Progress Report (Score)', 'Practicum Narrative Report (Score)', 
    #  'Practicum Coordinator Evaluation (Score)', 'Practicum Partner Supervisor Evaluation (Score)', 
    #  'Attendance (Days Present out of 25)']
    
    features = {}
    
    # Map each expected feature name to snapshot value
    for feature_name in FEATURE_NAMES:
        if feature_name == 'Weekly Progress Report (Score)':
            features[feature_name] = float(snapshot.get("daily_progress_score", 0))
        elif feature_name == 'Practicum Narrative Report (Score)':
            features[feature_name] = float(snapshot.get("narrative_score", 0))
        elif feature_name == 'Practicum Coordinator Evaluation (Score)':
            features[feature_name] = float(snapshot.get("coord_eval_score", 0))
        elif feature_name == 'Practicum Partner Supervisor Evaluation (Score)':
            features[feature_name] = float(snapshot.get("partner_eval_score", 0))
        elif feature_name == 'Attendance (Days Present out of 25)':
            features[feature_name] = float(snapshot.get("attendance_days_present", 0))
        else:
            # Default to 0 for any unknown features
            features[feature_name] = 0.0
    
    # Ensure all values are numeric and handle None/NaN
    for key, value in features.items():
        try:
            features[key] = float(value) if value is not None else 0.0
            if np.isnan(features[key]) or np.isinf(features[key]):
                features[key] = 0.0
        except (ValueError, TypeError):
            features[key] = 0.0
    
    return features


# =========================================================
# Risk Level Mapping
# =========================================================
def map_label_to_risk_level(predicted_label: str) -> str:
    """
    Map predicted label to risk level (HIGH, MEDIUM, LOW).
    
    Args:
        predicted_label: The predicted class label from the model
    
    Returns:
        Risk level string: "HIGH", "MEDIUM", or "LOW"
    """
    label_lower = str(predicted_label).lower()
    
    # Common patterns for high risk
    high_risk_keywords = ['poor', 'failing', 'at risk', 'low', 'unsatisfactory', 'needs improvement']
    # Common patterns for medium risk
    medium_risk_keywords = ['average', 'satisfactory', 'fair', 'moderate', 'needs attention']
    # Common patterns for low risk
    low_risk_keywords = ['excellent', 'good', 'satisfactory', 'high', 'outstanding', 'above average']
    
    if any(keyword in label_lower for keyword in high_risk_keywords):
        return "HIGH"
    elif any(keyword in label_lower for keyword in medium_risk_keywords):
        return "MEDIUM"
    elif any(keyword in label_lower for keyword in low_risk_keywords):
        return "LOW"
    else:
        # Default mapping based on label value
        # If label is numeric or can be compared, use that
        try:
            # Try to extract numeric value if label contains numbers
            import re
            numbers = re.findall(r'\d+', label_lower)
            if numbers:
                num = int(numbers[0])
                if num < 50:
                    return "HIGH"
                elif num < 75:
                    return "MEDIUM"
                else:
                    return "LOW"
        except:
            pass
        
        # Default to MEDIUM if we can't determine
        return "MEDIUM"


# =========================================================
# Main Prediction Function
# =========================================================
def predict_performance(features_dict: Dict[str, float]) -> Dict[str, Any]:
    """
    Predict student performance using ensemble of three models.
    
    Args:
        features_dict: Dictionary mapping feature names to numeric values
    
    Returns:
        Dictionary containing:
        {
            "predicted_label": <string>,
            "probability": <float>,
            "class_probabilities": { <label>: prob, ... },
            "risk_level": "HIGH" | "MEDIUM" | "LOW"
        }
    """
    if not MODELS_LOADED:
        raise ValueError("Models not loaded. Cannot make predictions.")
    
    if not FEATURE_NAMES:
        raise ValueError("Feature names not available.")
    
    # Order feature values according to FEATURE_NAMES
    feature_array = np.array([[features_dict.get(feature_name, 0.0) for feature_name in FEATURE_NAMES]])
    
    # Ensure all values are numeric
    feature_array = np.nan_to_num(feature_array, nan=0.0, posinf=0.0, neginf=0.0)
    
    # Scale features for LR and NB
    feature_array_scaled = SCALER.transform(feature_array)
    
    # Get probabilities from each model
    lr_proba = LR_MODEL.predict_proba(feature_array_scaled)
    rf_proba = RF_MODEL.predict_proba(feature_array)
    nb_proba = NB_MODEL.predict_proba(feature_array_scaled)
    
    # Combine via weighted average (weights: 0.4, 0.4, 0.2)
    ensemble_proba = (
        MODEL_WEIGHTS[0] * lr_proba +
        MODEL_WEIGHTS[1] * rf_proba +
        MODEL_WEIGHTS[2] * nb_proba
    )
    
    # Get predicted class index
    predicted_index = np.argmax(ensemble_proba[0])
    
    # Decode label with LABEL_ENCODER
    predicted_label = LABEL_ENCODER.inverse_transform([predicted_index])[0]
    
    # Get probability of predicted class
    probability = float(ensemble_proba[0][predicted_index])
    
    # Build class probabilities dictionary
    class_probabilities = {}
    for i, class_label in enumerate(LABEL_ENCODER.classes_):
        class_probabilities[str(class_label)] = float(ensemble_proba[0][i])
    
    # Map to risk level
    risk_level = map_label_to_risk_level(predicted_label)
    
    return {
        "predicted_label": str(predicted_label),
        "probability": probability,
        "class_probabilities": class_probabilities,
        "risk_level": risk_level
    }

