import os
import pickle
import numpy as np
import requests
import logging
from typing import Dict, Any, List, Optional, Tuple
from integrity_engine import assess_integrity_score

# =========================================================
# Setup Logging
# =========================================================
log_file = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'ai_engine.log')
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# =========================================================
# Directory Setup
# =========================================================
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_DIR = os.path.join(BASE_DIR, "../models")

# =========================================================
# Model Loading (Load once at module import)
# =========================================================
# Individual model/artifact variables
LR_MODEL = None
RF_MODEL = None
NB_MODEL = None
SCALER = None
LABEL_ENCODER = None
FEATURE_NAMES = None
MODELS_LOADED = False

def _load_model_safely(filename: str, model_name: str) -> Optional[Any]:
    """
    Safely load a pickled model/artifact from disk.
    
    Args:
        filename: Name of the pickle file to load
        model_name: Human-readable name for logging
    
    Returns:
        Loaded object or None if loading fails
    """
    filepath = os.path.join(MODEL_DIR, filename)
    try:
        if not os.path.exists(filepath):
            logger.error(f"❌ Model file not found: {filepath}")
            return None
        
        with open(filepath, 'rb') as f:
            model = pickle.load(f)
        logger.info(f"✅ Loaded {model_name} successfully")
        return model
    except Exception as e:
        logger.error(f"❌ Failed to load {model_name} from {filepath}: {e}")
        return None

# Load all models and artifacts
try:
    LR_MODEL = _load_model_safely("logistic_regression.pkl", "Logistic Regression")
    RF_MODEL = _load_model_safely("random_forest.pkl", "Random Forest")
    NB_MODEL = _load_model_safely("naive_bayes.pkl", "Naive Bayes")
    SCALER = _load_model_safely("scaler.pkl", "Scaler")
    LABEL_ENCODER = _load_model_safely("label_encoder.pkl", "Label Encoder")
    FEATURE_NAMES = _load_model_safely("feature_names.pkl", "Feature Names")
    
    # Validate all critical components are loaded
    critical_components = {
        'LR_MODEL': LR_MODEL,
        'RF_MODEL': RF_MODEL,
        'NB_MODEL': NB_MODEL,
        'SCALER': SCALER,
        'LABEL_ENCODER': LABEL_ENCODER,
        'FEATURE_NAMES': FEATURE_NAMES
    }
    
    missing_components = [name for name, component in critical_components.items() if component is None]
    
    if missing_components:
        MODELS_LOADED = False
        logger.error(f"❌ Failed to load critical components: {', '.join(missing_components)}")
    else:
        MODELS_LOADED = True
        logger.info(f"✅ All models loaded successfully. Features: {FEATURE_NAMES}")
        
except Exception as e:
    MODELS_LOADED = False
    logger.error(f"❌ Critical error during model loading: {e}")

# Ensemble weights (LR, RF, NB) — loaded from training or fallback to equal
_loaded_weights = _load_model_safely("model_weights.pkl", "Model Weights")
MODEL_WEIGHTS = _loaded_weights if _loaded_weights is not None else np.array([1/3, 1/3, 1/3])

# Required input fields for prediction (minimum set for validation)
# Note: During live prediction, supervisor_eval_grade may be missing (0 or null)
REQUIRED_SNAPSHOT_FIELDS = [
    "total_hours_completed",
    "required_hours",
    "attendance_rate"
]


# =========================================================
# Model Validation Helper
# =========================================================
def validate_models() -> Tuple[bool, Optional[Dict[str, Any]]]:
    """
    Validate that all required models and artifacts are loaded.
    
    Returns:
        Tuple of (is_valid, error_dict)
        - is_valid: True if all models are available
        - error_dict: Error response dict if validation fails, None otherwise
    """
    if not MODELS_LOADED:
        return False, {
            "success": False,
            "error_type": "MODEL_NOT_AVAILABLE",
            "message": "Prediction service is temporarily unavailable. Please contact the system administrator.",
            "details": "One or more required ML models failed to load during system startup."
        }
    
    # Check each critical component
    if LR_MODEL is None:
        return False, {
            "success": False,
            "error_type": "MODEL_NOT_AVAILABLE",
            "message": "Prediction service is temporarily unavailable. Please contact the system administrator.",
            "details": "Logistic Regression model is missing."
        }
    
    if RF_MODEL is None:
        return False, {
            "success": False,
            "error_type": "MODEL_NOT_AVAILABLE",
            "message": "Prediction service is temporarily unavailable. Please contact the system administrator.",
            "details": "Random Forest model is missing."
        }
    
    if NB_MODEL is None:
        return False, {
            "success": False,
            "error_type": "MODEL_NOT_AVAILABLE",
            "message": "Prediction service is temporarily unavailable. Please contact the system administrator.",
            "details": "Naive Bayes model is missing."
        }
    
    if SCALER is None:
        return False, {
            "success": False,
            "error_type": "MODEL_NOT_AVAILABLE",
            "message": "Prediction service is temporarily unavailable. Please contact the system administrator.",
            "details": "Feature scaler is missing."
        }
    
    if LABEL_ENCODER is None:
        return False, {
            "success": False,
            "error_type": "MODEL_NOT_AVAILABLE",
            "message": "Prediction service is temporarily unavailable. Please contact the system administrator.",
            "details": "Label encoder is missing."
        }
    
    if FEATURE_NAMES is None or len(FEATURE_NAMES) == 0:
        return False, {
            "success": False,
            "error_type": "MODEL_NOT_AVAILABLE",
            "message": "Prediction service is temporarily unavailable. Please contact the system administrator.",
            "details": "Feature names configuration is missing."
        }
    
    return True, None


# =========================================================
# Input Validation Helper
# =========================================================
def validate_input(snapshot: Dict[str, Any]) -> Tuple[bool, Optional[Dict[str, Any]]]:
    """
    Validate that all required input fields are present and valid.
    
    Args:
        snapshot: Student snapshot dictionary from API
    
    Returns:
        Tuple of (is_valid, error_dict)
        - is_valid: True if input is valid
        - error_dict: Error response dict if validation fails, None otherwise
    """
    if not isinstance(snapshot, dict):
        return False, {
            "success": False,
            "error_type": "INVALID_INPUT",
            "message": "One or more required fields for prediction are missing or invalid.",
            "missing_fields": REQUIRED_SNAPSHOT_FIELDS,
            "details": "Input must be a dictionary/JSON object."
        }
    
    # Check for missing required fields
    missing_fields = []
    invalid_fields = []
    
    for field in REQUIRED_SNAPSHOT_FIELDS:
        if field not in snapshot:
            missing_fields.append(field)
        else:
            value = snapshot[field]
            # Check if value is numeric (int or float)
            if value is None:
                missing_fields.append(field)
            elif not isinstance(value, (int, float)):
                # Try to convert to float
                try:
                    float(value)
                except (ValueError, TypeError):
                    invalid_fields.append(f"{field} (got {type(value).__name__}, expected number)")
    
    if missing_fields or invalid_fields:
        error_dict = {
            "success": False,
            "error_type": "INVALID_INPUT",
            "message": "One or more required fields for prediction are missing or invalid.",
            "missing_fields": missing_fields,
            "invalid_fields": invalid_fields if invalid_fields else None
        }
        
        logger.warning(f"Input validation failed: missing={missing_fields}, invalid={invalid_fields}")
        return False, error_dict
    
    # All validations passed
    return True, None


# =========================================================
# Forecasted Grade Calculation
# =========================================================
def calculate_forecasted_grade(snapshot: Dict[str, Any]) -> Dict[str, Any]:
    """
    Calculates the forecasted final OJT grade based on official university weights:
    - Weekly Progress Report (WPR): 20%
    - Narrative Report (NR): 20%
    - Coordinator Evaluation (CE): 20%
    - Supervisor Evaluation (SE): 40%
    
    If some components are missing (e.g. SE is usually given at the end), 
    the grade is forecasted by redistributing weights proportionally among available components.
    """
    wpr = float(snapshot.get("weekly_progress_grade", 0.0))
    nr = float(snapshot.get("narrative_report_grade", 0.0))
    ce = float(snapshot.get("coordinator_eval_grade", 0.0))
    se = float(snapshot.get("supervisor_eval_grade", 0.0))
    
    has_wpr = float(snapshot.get("has_weekly_progress_grade", 0)) > 0
    has_nr = float(snapshot.get("has_narrative_report_grade", 0)) > 0
    has_ce = float(snapshot.get("has_coordinator_eval_grade", 0)) > 0
    has_se = float(snapshot.get("has_supervisor_eval_grade", 0)) > 0
    
    # Base weights
    weights = {
        "wpr": 0.20 if has_wpr else 0.0,
        "nr": 0.20 if has_nr else 0.0,
        "ce": 0.20 if has_ce else 0.0,
        "se": 0.40 if has_se else 0.0
    }
    
    total_active_weight = sum(weights.values())
    raw_total = (wpr * 0.20) + (nr * 0.20) + (ce * 0.20) + (se * 0.40)
    
    if total_active_weight == 0:
        forecasted_grade = 0.0
    else:
        # Forecasted grade normalizes the active weights to 100%
        forecasted_grade = ((wpr * weights["wpr"]) + (nr * weights["nr"]) + 
                           (ce * weights["ce"]) + (se * weights["se"])) / total_active_weight
                           
    return {
        "status": "partial" if total_active_weight < 1.0 else "complete",
        "raw_score": round(raw_total, 2),
        "forecasted_grade": round(forecasted_grade, 2),
        "available_weight_percent": round(total_active_weight * 100),
        "components": {
            "weekly_progress": { "score": round(wpr, 2), "weight": "20%", "available": has_wpr },
            "narrative_report": { "score": round(nr, 2), "weight": "20%", "available": has_nr },
            "coordinator_eval": { "score": round(ce, 2), "weight": "20%", "available": has_ce },
            "supervisor_eval": { "score": round(se, 2), "weight": "40%", "available": has_se }
        }
    }


# =========================================================
# Feature Mapping from Snapshot
# =========================================================
def build_features_from_snapshot(snapshot: Dict[str, Any]) -> Dict[str, float]:
    """
    Convert comprehensive student snapshot to model feature dictionary.
    
    This function maps the comprehensive multi-feature snapshot from the backend
    to the feature names expected by the trained model, using the exact order
    from feature_names.pkl.
    
    Args:
        snapshot: Comprehensive student state from backend with 30+ features:
            {
                "total_hours_completed": 150.0,
                "required_hours": 300,
                "attendance_rate": 75.0,
                "late_count": 2,
                "absent_count": 5,
                "hours_completed_ratio": 0.5,
                "total_tasks_logged": 20,
                "total_task_hours": 80.0,
                "number_of_distinct_competencies": 5,
                "hours_software_development": 40.0,
                "hours_machine_learning_engineering": 0.0,
                ... (all 11 competencies),
                "weekly_progress_grade": 85.0,
                "narrative_report_grade": 80.0,
                "coordinator_eval_grade": 88.0,
                "supervisor_eval_grade": 90.0,  # May be 0 during active OJT
                "has_weekly_progress_grade": 1,
                "has_narrative_report_grade": 1,
                "has_coordinator_eval_grade": 1,
                "has_supervisor_eval_grade": 1,  # May be 0 during active OJT
                "total_chatbot_queries": 15,
                "chatbot_queries_last_30_days": 8
            }
    
    Returns:
        Dictionary mapping feature names to numeric values (in exact order of FEATURE_NAMES)
    
    Raises:
        ValueError: If feature names are not loaded
    """
    if not FEATURE_NAMES:
        raise ValueError("Feature names not loaded. Models may not be initialized.")
    
    features = {}
    
    # Build features dictionary using exact feature names from feature_names.pkl
    # The backend sends features with exact names matching FEATURE_COLUMNS, so direct mapping should work
    for feature_name in FEATURE_NAMES:
        # Direct match (backend sends exact feature names)
        if feature_name in snapshot:
            value = snapshot[feature_name]
        else:
            # Fallback: try to find by pattern matching (for backward compatibility)
            value = None
            feature_lower = feature_name.lower()
            
            # Try common variations
            for key in snapshot.keys():
                if key.lower() == feature_lower or key.lower().replace('_', ' ') == feature_lower.replace('_', ' '):
                    value = snapshot[key]
                    break
            
            # If still not found, use 0.0
            if value is None:
                value = 0.0
        
        # Ensure value is numeric and handle None/NaN
        try:
            features[feature_name] = float(value) if value is not None else 0.0
            if np.isnan(features[feature_name]) or np.isinf(features[feature_name]):
                features[feature_name] = 0.0
        except (ValueError, TypeError):
            features[feature_name] = 0.0
    
    return features


# =========================================================
# Risk Level Mapping
# =========================================================
def map_label_to_risk_level(predicted_label: str, probability: float = None) -> str:
    """
    Map predicted label to canonical risk level (HIGH, MEDIUM, LOW).

    In this system the classifier is explicitly trained on the target
    labels "HIGH", "MEDIUM", "LOW" which are derived from the final
    OJT grade using the official grading formula.  To avoid any
    accidental re-interpretation, we simply normalize the model's
    output to these three categories.
    """
    label = str(predicted_label).strip().upper()
    if label in {"HIGH", "MEDIUM", "LOW"}:
        return label

    # Fallback: if the label is unexpected, use probability to choose.
    if probability is not None:
        if probability < 0.5:
            return "HIGH"
        elif probability < 0.7:
            return "MEDIUM"
        else:
            return "LOW"

    # Last resort default.
    return "MEDIUM"


# =========================================================
# Explainability Helpers
# =========================================================
def generate_top_reasons(
    features_dict: Dict[str, float],
    predicted_label: str,
    risk_level: str,
    rf_model: Any = None
) -> List[str]:
    """
    Generate top reasons for the prediction based on feature values and model insights.
    
    Args:
        features_dict: Dictionary of feature names to values
        predicted_label: Predicted class label
        risk_level: Risk level (HIGH, MEDIUM, LOW)
        rf_model: Optional Random Forest model to extract feature importances
    
    Returns:
        List of reason strings explaining the prediction
    """
    reasons = []
    
    # Get feature importances from Random Forest if available
    feature_importances = None
    if rf_model is not None and hasattr(rf_model, 'feature_importances_') and FEATURE_NAMES:
        try:
            importances = rf_model.feature_importances_
            feature_importances = dict(zip(FEATURE_NAMES, importances))
            # Sort by importance
            feature_importances = dict(sorted(feature_importances.items(), key=lambda x: x[1], reverse=True))
        except Exception as e:
            logger.warning(f"Could not extract feature importances: {e}")
    
    # Analyze attendance (using new feature names)
    attendance_rate = features_dict.get('attendance_rate', 0)
    total_hours = features_dict.get('total_hours_completed', 0)
    required_hours = features_dict.get('required_hours', 300)
    hours_ratio = features_dict.get('hours_completed_ratio', 0)
    
    if attendance_rate < 60:
        reasons.append(f"Low attendance rate ({attendance_rate:.1f}%) - impacts 20% Weekly Progress score")
    elif attendance_rate < 80:
        reasons.append(f"Attendance rate below target ({attendance_rate:.1f}%) - impacts 20% Weekly Progress score")
    
    if hours_ratio < 0.5:
        reasons.append(f"Low completed hours ({total_hours:.0f}/{required_hours:.0f} hours, {hours_ratio*100:.1f}% complete)")
    elif hours_ratio < 0.75:
        reasons.append(f"Hours completion below target ({hours_ratio*100:.1f}% complete)")
    
    # Analyze competency-based tasks
    total_tasks = features_dict.get('total_tasks_logged', 0)
    distinct_competencies = features_dict.get('number_of_distinct_competencies', 0)
    
    if total_tasks < 10:
        reasons.append(f"Few tasks logged ({total_tasks} tasks) - impacts 20% Weekly Progress score")
    elif distinct_competencies < 3:
        reasons.append(f"Limited competency diversity ({distinct_competencies} competencies)")
    
    # Analyze evaluation scores (using new feature names)
    coord_score = features_dict.get('coordinator_eval_grade', 
                                    features_dict.get('Practicum Coordinator Evaluation (Score)', 0))
    supervisor_score = features_dict.get('supervisor_eval_grade',
                                         features_dict.get('Practicum Partner Supervisor Evaluation (Score)', 0))
    narrative_score = features_dict.get('narrative_report_grade',
                                        features_dict.get('Practicum Narrative Report (Score)', 0))
    progress_score = features_dict.get('weekly_progress_grade',
                                       features_dict.get('Weekly Progress Report (Score)', 0))
    
    if coord_score < 70 and coord_score > 0:
        reasons.append(f"Low coordinator evaluation score ({coord_score:.1f})")
    elif coord_score > 90:
        reasons.append(f"Strong coordinator evaluation score ({coord_score:.1f})")
    
    if supervisor_score < 70 and supervisor_score > 0:
        reasons.append(f"Low supervisor evaluation score ({supervisor_score:.1f})")
    elif supervisor_score > 90:
        reasons.append(f"Strong supervisor evaluation score ({supervisor_score:.1f})")
    
    if narrative_score < 70 and narrative_score > 0:
        reasons.append(f"Low narrative report score ({narrative_score:.1f})")
    
    if progress_score < 70 and progress_score > 0:
        reasons.append(f"Low weekly progress score ({progress_score:.1f})")
    
    # Check for missing supervisor evaluation (common during active OJT)
    has_supervisor_eval = features_dict.get('has_supervisor_eval_grade', 0)
    if has_supervisor_eval == 0 and supervisor_score == 0:
        reasons.append("Supervisor evaluation not yet available (prediction based on other indicators)")
    
    # Use feature importances if available
    if feature_importances:
        try:
            iter_keys = iter(feature_importances.keys())
            top_feature = next(iter_keys)
            top_importance = feature_importances[top_feature]
            top_value = features_dict.get(top_feature, 0)
            
            # Create reason based on top feature
            if 'attendance' in top_feature.lower():
                if top_value < 15:
                    reasons.insert(0, f"Attendance is the most critical factor (only {top_value:.0f} days present)")
            elif top_value < 70:
                reasons.insert(0, f"{top_feature} is below satisfactory ({top_value:.1f})")
        except StopIteration:
            pass
    
    # Limit to top 5 reasons
    if len(reasons) > 5:
        reasons = list(reasons)[:5]
    
    # If no specific reasons found, provide generic one
    if not reasons:
        if risk_level == "HIGH":
            reasons.append("Multiple performance indicators suggest the student needs immediate attention")
        elif risk_level == "MEDIUM":
            reasons.append("Some performance areas need improvement")
        else:
            reasons.append("Overall performance is satisfactory")
    
    return reasons


def generate_recommendation(risk_level: str, reasons: List[str], features_dict: Dict[str, float]) -> str:
    """
    Generate an actionable recommendation based on risk level and reasons.
    
    Args:
        risk_level: Risk level (HIGH, MEDIUM, LOW)
        reasons: List of top reasons for the prediction
        features_dict: Dictionary of feature values
    
    Returns:
        Short, actionable recommendation string
    """
    attendance_rate = features_dict.get('attendance_rate', 0)
    hours_ratio = features_dict.get('hours_completed_ratio', 0)
    total_tasks = features_dict.get('total_tasks_logged', 0)
    distinct_competencies = features_dict.get('number_of_distinct_competencies', 0)
    
    if risk_level == "HIGH":
        if attendance_rate < 60:
            return "Immediate action required: Improve attendance consistency and coordinate with supervisor to address performance gaps. Focus on logging daily tasks across multiple competencies."
        elif hours_ratio < 0.5:
            return "High priority: Increase OJT hours completion. Log more competency-based daily tasks and ensure supervisor approval. Coordinate with supervisor for support."
        elif total_tasks < 10:
            return "Action required: Increase daily task logging and ensure tasks are linked to OJT competencies. Seek supervisor guidance on task variety."
        elif any('evaluation' in r.lower() for r in reasons):
            return "Schedule a meeting with the student and supervisor to develop an improvement plan focusing on evaluation feedback and competency development."
        else:
            return "High priority: Review all performance metrics (attendance, competencies, evaluations) and implement a structured intervention plan."
    
    elif risk_level == "MEDIUM":
        if attendance_rate < 80:
            return "Focus on improving attendance consistency and ensure all attendance records are approved by supervisor."
        elif hours_ratio < 0.75:
            return "Monitor hours completion progress. Increase competency-based task logging and ensure supervisor approval for all tasks."
        elif distinct_competencies < 5:
            return "Expand competency coverage. Log tasks across more OJT competencies to demonstrate diverse skill development."
        else:
            return "Monitor progress closely and provide targeted support in areas showing lower performance. Maintain regular check-ins."
    
    else:  # LOW risk
        if attendance_rate >= 80 and hours_ratio >= 0.75:
            return "Continue current performance. Maintain regular check-ins, keep logging competency-based tasks, and provide positive reinforcement."
        elif distinct_competencies >= 5:
            return "Excellent competency diversity. Continue maintaining attendance and task logging consistency."
        else:
            return "Good overall performance. Focus on maintaining consistency in attendance, task logging, and evaluations."
    
    # Default recommendation
    return "Continue monitoring and provide support as needed. Ensure all attendance and tasks are approved by supervisor."


# =========================================================
# Main Prediction Function (Enhanced with Explainability)
# =========================================================
def predict_performance(features_dict: Dict[str, float]) -> Dict[str, Any]:
    """
    Predict student performance using ensemble of three models.
    
    This function performs the core ML prediction and includes explainability features.
    
    Args:
        features_dict: Dictionary mapping feature names to numeric values
    
    Returns:
        Dictionary containing:
        {
            "success": true,
            "risk_level": "HIGH" | "MEDIUM" | "LOW",
            "predicted_label": <string>,
            "probabilities": {
                "<class_1>": <float>,
                "<class_2>": <float>,
                ...
            },
            "probability": <float>,  # Probability of predicted class
            "top_reasons": [
                "Low attendance in the last N days",
                ...
            ],
            "recommendation": "Short, actionable recommendation here.",
            "progress_score": <int>,
            "confidence": <float>,
            "prediction_stage": "early" | "developing" | "mature",
            "key_factors": [...],
            "recommendations": [...]
        }
        
        OR if models are unavailable:
        {
            "success": false,
            "error_type": "MODEL_NOT_AVAILABLE",
            "message": "...",
            "details": "..."
        }
    
    Required Input Features:
        - 'Weekly Progress Report (Score)': Numeric score (0-100)
        - 'Practicum Narrative Report (Score)': Numeric score (0-100)
        - 'Practicum Coordinator Evaluation (Score)': Numeric score (0-100)
        - 'Practicum Partner Supervisor Evaluation (Score)': Numeric score (0-100)
        - 'Attendance (Days Present out of 25)': Integer (0-25)
    
    Risk Levels:
        - HIGH: Student requires immediate attention and intervention
        - MEDIUM: Student needs monitoring and support
        - LOW: Student is performing satisfactorily
    """
    # Validate models are loaded
    models_valid, error_response = validate_models()
    if not models_valid:
        logger.error("Prediction attempted but models are not available")
        return error_response
    
    try:
        # Order feature values according to FEATURE_NAMES (exact order from feature_names.pkl)
        if not FEATURE_NAMES:
            raise ValueError("Feature names not loaded. Cannot build feature array.")
        
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
        probabilities = {}
        for i, class_label in enumerate(LABEL_ENCODER.classes_):
            probabilities[str(class_label)] = float(ensemble_proba[0][i])
        
        # Map to risk level
        risk_level = map_label_to_risk_level(str(predicted_label), probability)
        
        # Calculate Data Completeness and Stage
        hours_ratio = features_dict.get('hours_completed_ratio', 0)
        prediction_stage = "early"
        if hours_ratio >= 0.75:
            prediction_stage = "mature"
        elif hours_ratio >= 0.25:
            prediction_stage = "developing"
            
        has_supervisor_eval = features_dict.get('has_supervisor_eval_grade', 0)
        has_coord_eval = features_dict.get('has_coordinator_eval_grade', 0)
        has_tasks = features_dict.get('total_tasks_logged', 0) > 0

        data_completeness = {
            "has_supervisor_eval": bool(has_supervisor_eval),
            "has_coordinator_eval": bool(has_coord_eval),
            "has_tasks": bool(has_tasks)
        }
        
        # Generate explainability features
        top_reasons = generate_top_reasons(features_dict, str(predicted_label), risk_level, RF_MODEL)
        
        if prediction_stage == "early":
            early_reasons = []
            if not has_supervisor_eval: early_reasons.append("Supervisor evaluation not yet available")
            if not has_tasks: early_reasons.append("Task submissions have not started")
            early_reasons.append("Score is primarily based on attendance records and early data")
            # Overwrite for early stage to prioritize explainability when lacking data
            top_reasons = early_reasons + top_reasons[:2]

        recommendation = generate_recommendation(risk_level, top_reasons, features_dict)
        
        # Calculate 0-100 Progress Score based on ML probability
        # If LOW risk: 80 - 100
        # If MEDIUM risk: 50 - 79
        # If HIGH risk: 0 - 49
        
        # First, ensure probability is for the predicted class
        # (Usually probability is high for predicted class, so e.g. 0.9 Low Risk => score 98)
        
        progress_score = 0
        if risk_level == "LOW":
            progress_score = 80 + (probability * 20)  # Maps 0-1 prob to 80-100 range roughly
        elif risk_level == "MEDIUM":
            progress_score = 50 + (probability * 29)  # Maps 0-1 prob to 50-79 range roughly
        else: # HIGH
            progress_score = max(0.0, 49.0 - (probability * 49.0))  # Higher confidence of HIGH risk = lower score

            
        progress_score = min(100, max(0, int(progress_score)))
        
        # Build unified JSON schema elements (alongside backward-compatible keys)
        return {
            "success": True,
            # Backward-compatible fields
            "risk_level": risk_level,
            "predicted_label": str(predicted_label),
            "probabilities": probabilities,
            "probability": float(probability),
            "top_reasons": top_reasons,
            "recommendation": recommendation,
            
            # New Unified Schema fields strictly matching payload requirements
            "summary": recommendation,
            "progress_score": progress_score,
            "score": progress_score,
            "confidence": float(probability),
            "prediction_stage": prediction_stage,
            "top_reasons": top_reasons,
            "key_factors": top_reasons,
            "data_completeness": data_completeness,
            "recommendations": [recommendation] # Overwritten by Gemma if enabled
        }
    
    except Exception as e:
        logger.error(f"Error during prediction: {e}", exc_info=True)
        return {
            "success": False,
            "error_type": "PREDICTION_ERROR",
            "message": "An error occurred during prediction processing.",
            "details": str(e)
        }


# =========================================================
# ML Prediction (Pure ML - No LLM) - Backward Compatible
# =========================================================
def ml_predict(features_dict: Dict[str, float]) -> Dict[str, Any]:
    """
    Pure ML prediction function (no LLM).
    This is the numeric backbone for risk assessment.
    
    This function maintains backward compatibility with existing code that expects
    the old response format.
    
    Args:
        features_dict: Dictionary mapping feature names to numeric values
    
    Returns:
        Dictionary containing:
        {
            "class_label": <string>,
            "probability": <float>,
            "risk_level": "HIGH" | "MEDIUM" | "LOW",
            "class_probabilities": { <label>: prob, ... }
        }
        
        OR error dict if models unavailable
    """
    result = predict_performance(features_dict)
    
    # If error response, return as-is
    if not result.get("success", False):
        return result
    
    # Rename keys to match expected format (backward compatibility)
    return {
        "class_label": result["predicted_label"],
        "probability": result["probability"],
        "risk_level": result["risk_level"],
        "class_probabilities": result["probabilities"]
    }


# =========================================================
# Gemma (Ollama) Integration
# =========================================================
def call_gemma(prompt: str, model: str = None, timeout: int = 180) -> str:
    """
    Call local Ollama instance running Gemma model.
    
    Args:
        prompt: The prompt to send to Gemma
        model: Ollama model name (default: "gemma2:2b")
        timeout: Request timeout in seconds (default: 60)
    
    Returns:
        Generated text response from Gemma
    
    Raises:
        requests.RequestException: If the request fails
    """
    ollama_url = os.getenv("OLLAMA_URL", "http://127.0.0.1:11434/api/generate")
    
    # Use environment variable or default to gemma2:2b (can be overridden)
    if model is None:
        model = os.getenv("OLLAMA_MODEL", "gemma2:2b")
    
    try:
        response = requests.post(
            ollama_url,
            json={
                "model": model,
                "prompt": prompt,
                "stream": False
            },
            timeout=timeout
        )
        response.raise_for_status()
        data = response.json()
        
        # Ollama API returns response in "response" field
        text = data.get("response", "")
        if not text:
            # Fallback to other possible keys
            text = data.get("output", "") or data.get("text", "")
        
        return text.strip()
    
    except requests.exceptions.ConnectionError:
        raise ConnectionError(
            f"Cannot connect to Ollama at {ollama_url}. "
            "Please ensure Ollama is running and the model is available."
        )
    except requests.exceptions.Timeout:
        raise TimeoutError(f"Ollama request timed out after {timeout} seconds.")
    except requests.exceptions.RequestException as e:
        raise Exception(f"Ollama API error: {str(e)}")


def parse_gemma_response(response_text: str) -> Dict[str, str]:
    """
    Parse Gemma's response into explanation and recommendations.
    
    Args:
        response_text: Raw response from Gemma
    
    Returns:
        Dictionary with "explanation" and "recommendations" keys
    """
    # Try to split by common patterns
    lines = response_text.split('\n')
    
    explanation_parts = []
    recommendations = []
    
    in_recommendations = False
    
    for line in lines:
        line = line.strip()
        if not line:
            continue
        
        # Check if this looks like a recommendation (numbered, bulleted, etc.)
        if (line.startswith(('1.', '2.', '3.', '4.', '5.', '-', '•', '*')) or
            'recommendation' in line.lower() or 'suggestion' in line.lower()):
            in_recommendations = True
            # Clean up the line
            clean_line = line.lstrip('1234567890.-•* ').strip()
            if clean_line:
                recommendations.append(clean_line)
        else:
            if in_recommendations:
                # Continue adding to recommendations if we're in that section
                recommendations.append(line)
            else:
                explanation_parts.append(line)
    
    explanation = ' '.join(explanation_parts) if explanation_parts else response_text
    
    # If no recommendations found, return everything as explanation
    if not recommendations:
        return {
            "explanation": response_text,
            "recommendations": []
        }
    
    return {
        "explanation": explanation,
        "recommendations": recommendations[:5]  # Limit to 5 recommendations
    }


# =========================================================
# Hybrid ML + Gemma Prediction (Enhanced)
# =========================================================
def predict_with_explanation(snapshot: Dict[str, Any]) -> Dict[str, Any]:
    """
    Combined ML prediction + Gemma explanation and recommendations.
    
    This function validates input, runs ML prediction, and optionally calls
    Gemma for additional explanation. Returns structured response with error
    handling.
    
    Steps:
    1. Validate input snapshot
    2. Convert snapshot -> features_dict
    3. Run predict_performance(features_dict) to get risk assessment
    4. Build prompt for Gemma using ML results (optional)
    5. Call Gemma to generate explanation and recommendations (optional, if available)
    6. Return combined result
    
    Args:
        snapshot: Student snapshot from backend, e.g.
            {
                "daily_progress_score": 82,
                "narrative_score": 85,
                "coord_eval_score": 88,
                "partner_eval_score": 90,
                "attendance_days_present": 18
            }
    
    Returns:
        Dictionary containing:
        {
            "success": true,
            "ml_prediction": {
                "risk_level": "HIGH" | "MEDIUM" | "LOW",
                "predicted_label": <string>,
                "probability": <float>,
                "probabilities": { ... },
                "top_reasons": [...],
                "recommendation": "..."
            },
            "gemma_explanation": <string>,
            "gemma_recommendations": [<list of strings>]
        }
        
        OR error dict with success: false if validation or prediction fails
    """
    # Step 1: Validate input
    input_valid, error_response = validate_input(snapshot)
    if not input_valid:
        logger.warning(f"Input validation failed for snapshot: {snapshot}")
        return error_response
    
    # Step 1.5: Early-stage detection — return a sensible fallback for students just starting OJT
    total_hours = float(snapshot.get('total_hours_completed', 0))
    attendance_rate = float(snapshot.get('attendance_rate', 0))
    total_tasks = float(snapshot.get('total_tasks_logged', 0))
    required_hours = float(snapshot.get('required_hours', 300))
    hours_ratio = total_hours / required_hours if required_hours > 0 else 0.0
    
    # Made flexible: Only show early stage fallback if the student has absolutely zero data
    IS_EARLY_STAGE = total_hours <= 0 and total_tasks <= 0
    
    if IS_EARLY_STAGE:
        logger.info(f"Early OJT stage detected (hours={total_hours}, tasks={total_tasks}). Returning warm-start prediction.")
        grading_result = calculate_forecasted_grade(snapshot)
        integrity_result = assess_integrity_score(
            inside_geofence=snapshot.get('inside_geofence', True),
            distance_m=snapshot.get('distance_m', 0.0),
            accuracy_m=snapshot.get('accuracy_m', 10.0),
            trust_flags=snapshot.get('trust_flags', ''),
            has_photo=snapshot.get('has_photo', True),
            recent_flags_count=snapshot.get('recent_flags_count', 0)
        )
        early_summary = (
            "The student is in the early stage of OJT. Not enough data yet for a full ML prediction. "
            "Keep logging daily tasks and attendance consistently."
        )
        return {
            "success": True,
            "early_stage": True,
            "risk_level": "LOW",
            "predicted_label": "LOW",
            "probability": 0.5,
            "probabilities": {"LOW": 0.5, "MEDIUM": 0.3, "HIGH": 0.2},
            "top_reasons": ["Student just started OJT. Insufficient data for full prediction."],
            "recommendation": early_summary,
            "summary": early_summary,
            "score": 50,
            "confidence": 0.5,
            "key_factors": ["Early OJT stage", f"Hours completed: {total_hours:.0f} / {required_hours:.0f}"],
            "trend": {"status": "Stable", "reason": "OJT just started"},
            "integrity": integrity_result,
            "grading": grading_result,
            "ml_prediction": {
                "success": True,
                "risk_level": "LOW",
                "probability": 0.5,
                "score": 50,
                "key_factors": ["Early OJT stage. Log tasks and attendance to unlock predictions."],
            },
            "gemma_explanation": early_summary,
            "gemma_recommendations": [
                "Log your daily tasks regularly in the app.",
                "Ensure each attendance entry is approved by your supervisor.",
                "Explore multiple OJT competencies early."
            ]
        }
    
    try:
        # Step 2: Convert snapshot to features
        features_dict = build_features_from_snapshot(snapshot)
        
        # Step 3: Run ML prediction (with explainability)
        ml_result = predict_performance(features_dict)
        
        # Step 3.5: Run Integrity Assessment and Trend Extraction
        inside_geofence = snapshot.get("inside_geofence", True)
        distance_m = snapshot.get("distance_m", 0.0)
        accuracy_m = snapshot.get("accuracy_m", 10.0)
        trust_flags = snapshot.get("trust_flags", "")
        has_photo = snapshot.get("has_photo", True)
        recent_flags_count = snapshot.get("recent_flags_count", 0)
        
        integrity_result = assess_integrity_score(
            inside_geofence=inside_geofence,
            distance_m=distance_m,
            accuracy_m=accuracy_m,
            trust_flags=trust_flags,
            has_photo=has_photo,
            recent_flags_count=recent_flags_count
        )
        
        trend_result = {
            "status": snapshot.get("trend_status", "stable"),
            "reason": snapshot.get("trend_reason", "Performance is consistent")
        }
        
        # If ML prediction failed, return error
        if not ml_result.get("success", False):
            return ml_result
        
        # Step 4: Build prompt for Gemma (optional, if Ollama is available)
        # Format features for display
        features_summary = "\n".join([
            f"- {name}: {value:.1f}" 
            for name, value in features_dict.items()
        ])
        
        student_name = snapshot.get("student_name", "Student")
        
        prompt = f"""You are an academic advisor for OJT (on-the-job training) students.

Student performance summary for {student_name}:
- Risk level: {ml_result['risk_level']}
- Predicted class: {ml_result['predicted_label']}
- Confidence: {ml_result['probability']:.1%}
- Key concerns: {', '.join(ml_result['top_reasons'][:3])}

Performance metrics (higher is better):
{features_summary}

Please provide:
1) A brief explanation (2-3 sentences) in simple, encouraging language explaining why {student_name} is at this risk level. Be supportive and constructive. Start with a greeting using the student's name: "Hi {student_name}, ...".

2) Give 3-5 specific, practical recommendations {student_name} can follow in the next 1-2 weeks to improve their OJT performance. Focus on actionable steps related to attendance, evaluations, tasks, communication, etc.

Keep your total response under 250 words. Format recommendations as numbered or bulleted items. Speak as if you are their mentor."""

        # Step 5: Call Gemma (optional, failures won't break the response)
        gemma_explanation = ""
        gemma_recommendations = []
        
        try:
            gemma_response = call_gemma(prompt)
            parsed = parse_gemma_response(gemma_response)
            gemma_explanation = parsed["explanation"]
            gemma_recommendations = parsed["recommendations"]
        except Exception as e:
            # If Gemma fails, log but don't fail the entire prediction
            logger.warning(f"Gemma call failed (ML prediction still available): {e}")
            gemma_explanation = f"AI explanation service is currently unavailable. Please refer to the ML prediction recommendations above."
            gemma_recommendations = []
        
        # Step 6: Return combined result fitting the Unified Schema
        unified_response = ml_result.copy()
        
        if gemma_explanation:
            unified_response["summary"] = gemma_explanation
            # Use Gemma recommendations if we have them, else fall back to ML recommendation format
            if gemma_recommendations:
                unified_response["recommendations"] = gemma_recommendations
                
        # To maintain exact legacy contract format while supporting unified schema
        unified_response["ml_prediction"] = ml_result
        unified_response["gemma_explanation"] = unified_response.get("summary", "")
        unified_response["gemma_recommendations"] = unified_response.get("recommendations", [])
        
        # Inject structural blocks
        unified_response["trend"] = trend_result
        unified_response["integrity"] = integrity_result
        unified_response["grading"] = calculate_forecasted_grade(snapshot)
                
        return unified_response
    
    except Exception as e:
        logger.error(f"Error in predict_with_explanation: {e}", exc_info=True)
        return {
            "success": False,
            "error_type": "PREDICTION_ERROR",
            "message": "An error occurred during prediction processing.",
            "details": str(e)
        }
