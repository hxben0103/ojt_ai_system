# scripts/train_model.py
# 
# OJT Performance Prediction Model Training
# 
# This script trains an ensemble model using PREDICTIVE features only:
# - Attendance metrics (approved only)
# - Competency-based daily task data (11 competencies)
# - Chatbot engagement metrics
#
# Grading components (WPR, NR, CE, SE) are EXCLUDED from features because
# the target variable (risk_level) is derived from those same grades,
# which would cause data leakage.
#
# The model predicts risk levels (HIGH, MEDIUM, LOW) based on leading
# indicators that are available during active OJT.

import pandas as pd
import numpy as np
import pickle
import os
import sys
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import RandomForestClassifier
from sklearn.naive_bayes import GaussianNB
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.model_selection import train_test_split, StratifiedKFold, cross_val_score
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
import warnings
warnings.filterwarnings('ignore')

# Add parent directory to path to import modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Import preprocessor — use PREDICTIVE_FEATURE_COLUMNS (no grading leakage)
from data.processing.processdata import (
    OJTDataPreprocessor, FEATURE_COLUMNS, PREDICTIVE_FEATURE_COLUMNS
)

# OJT Grading Component Weights (as per institutional requirements)
WPR_WEIGHT = 0.20  # Weekly Progress Report
NR_WEIGHT = 0.20   # Narrative Report
CE_WEIGHT = 0.20   # Coordinator Evaluation
SE_WEIGHT = 0.40   # Supervisor Evaluation

class EnsembleModel:
    """
    Ensemble model that combines Logistic Regression, Random Forest, and Naive Bayes
    Uses weighted averaging based on individual model performance
    """
    
    def __init__(self):
        self.lr_model = None
        self.rf_model = None
        self.nb_model = None
        self.scaler = None
        self.label_encoder = None
        self.model_weights = None
        self.classes_ = None
        self.feature_names = None
        
    def fit(self, X, y, feature_names=None, lr_weight=None, rf_weight=None, nb_weight=None):
        """
        Train all three models.
        
        If weights are None, they are learned from validation accuracy.
        """
        self.feature_names = feature_names
        
        # Encode labels if they're strings
        self.label_encoder = LabelEncoder()
        y_encoded = self.label_encoder.fit_transform(y)
        self.classes_ = self.label_encoder.classes_
        
        print(f"🎯 Training on {len(self.classes_)} classes: {list(self.classes_)}")
        
        # Scale features for Logistic Regression and Naive Bayes
        self.scaler = StandardScaler()
        X_scaled = self.scaler.fit_transform(X)
        
        # Train individual models
        print("📊 Training Logistic Regression...")
        self.lr_model = LogisticRegression(
            random_state=42, 
            max_iter=1000,
            C=1.0
        )
        self.lr_model.fit(X_scaled, y_encoded)
        
        print("🌲 Training Random Forest...")
        self.rf_model = RandomForestClassifier(
            n_estimators=100, 
            random_state=42,
            max_depth=10,
            min_samples_split=5
        )
        self.rf_model.fit(X, y_encoded)
        
        print("🎯 Training Naive Bayes...")
        self.nb_model = GaussianNB()
        self.nb_model.fit(X_scaled, y_encoded)
        
        # Learn weights from validation accuracy if not provided
        if lr_weight is None or rf_weight is None or nb_weight is None:
            lr_acc = accuracy_score(y_encoded, self.lr_model.predict(X_scaled))
            rf_acc = accuracy_score(y_encoded, self.rf_model.predict(X))
            nb_acc = accuracy_score(y_encoded, self.nb_model.predict(X_scaled))
            total = lr_acc + rf_acc + nb_acc
            lr_weight = lr_acc / total
            rf_weight = rf_acc / total
            nb_weight = nb_acc / total
            print(f"⚖️ Learned weights from training accuracy:")
            print(f"   LR: {lr_weight:.3f} (acc={lr_acc:.4f})")
            print(f"   RF: {rf_weight:.3f} (acc={rf_acc:.4f})")
            print(f"   NB: {nb_weight:.3f} (acc={nb_acc:.4f})")
        else:
            print(f"⚖️ Using provided weights - LR: {lr_weight}, RF: {rf_weight}, NB: {nb_weight}")
        
        self.model_weights = np.array([lr_weight, rf_weight, nb_weight])
        
        return self
    
    def predict_proba(self, X):
        """
        Get weighted average probabilities from all models
        """
        X_scaled = self.scaler.transform(X)
        
        # Get probabilities from each model
        lr_proba = self.lr_model.predict_proba(X_scaled)
        rf_proba = self.rf_model.predict_proba(X)
        nb_proba = self.nb_model.predict_proba(X_scaled)
        
        # Weighted average of probabilities
        weighted_proba = (self.model_weights[0] * lr_proba + 
                         self.model_weights[1] * rf_proba + 
                         self.model_weights[2] * nb_proba)
        
        return weighted_proba
    
    def predict(self, X):
        """
        Predict class labels using weighted probabilities
        """
        probabilities = self.predict_proba(X)
        predicted_indices = np.argmax(probabilities, axis=1)
        return self.label_encoder.inverse_transform(predicted_indices)
    
    def predict_single(self, features_dict):
        """
        Predict for a single student using feature dictionary
        """
        if self.feature_names is None:
            raise ValueError("Feature names not set during training")
        
        feature_array = np.array([[features_dict[feature] for feature in self.feature_names]])
        
        prediction = self.predict(feature_array)[0]
        probability = np.max(self.predict_proba(feature_array))
        
        return {
            'prediction': prediction,
            'confidence': float(probability),
            'probabilities': dict(zip(self.classes_, self.predict_proba(feature_array)[0]))
        }


def load_and_preprocess_data():
    """
    Load and preprocess the OJT grading data from CSV using OJTDataPreprocessor.
    Uses PREDICTIVE_FEATURE_COLUMNS (no grading components) to avoid data leakage.
    """
    # Resolve dataset path relative to the ai_module root so it works
    # no matter where the script is executed from.
    module_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    data_path = os.path.join(module_root, "data", "datasets", "ojt_grading_data.csv")
    
    if not os.path.exists(data_path):
        raise FileNotFoundError(f"❌ Dataset not found at {data_path}")
    
    print("📁 Loading dataset...")
    preprocessor = OJTDataPreprocessor()
    df = preprocessor.load_data(data_path)
    
    # Fit and transform the data (creates all columns including grading ones)
    df_processed, _, target_column, _ = preprocessor.fit(df)
    
    # Use PREDICTIVE features only — excludes grading components to prevent
    # data leakage (target is derived from those same grades)
    feature_columns = PREDICTIVE_FEATURE_COLUMNS
    print(f"\n🛡️  Using {len(feature_columns)} PREDICTIVE features (grading columns excluded)")
    print(f"   Excluded: WPR, NR, CE, SE grades and their has_* flags")
    
    # Extract X and y
    X = df_processed[feature_columns].values
    y = df_processed[target_column].values
    
    print(f"\n🎯 Target distribution:")
    target_counts = pd.Series(y).value_counts()
    for category, count in target_counts.items():
        print(f"   {category}: {count} ({count/len(y)*100:.1f}%)")
    
    print(f"\n📈 Feature statistics (sample):")
    for i, feature in enumerate(feature_columns[:5]):  # Show first 5
        print(f"   {feature}: min={X[:, i].min():.1f}, max={X[:, i].max():.1f}, mean={X[:, i].mean():.1f}")
    if len(feature_columns) > 5:
        print(f"   ... and {len(feature_columns) - 5} more features")
    
    return X, y, feature_columns, df_processed

def evaluate_model(ensemble, X_test, y_test, feature_names):
    """
    Comprehensive evaluation of the ensemble model with confusion matrix and feature importance
    """
    print("\n" + "="*50)
    print("🎯 MODEL EVALUATION")
    print("="*50)
    
    # Individual model evaluations
    X_test_scaled = ensemble.scaler.transform(X_test)
    
    print("\n📊 INDIVIDUAL MODEL PERFORMANCE:")
    
    # Logistic Regression
    lr_pred = ensemble.lr_model.predict(X_test_scaled)
    lr_pred_labels = ensemble.label_encoder.inverse_transform(lr_pred)
    lr_accuracy = accuracy_score(y_test, lr_pred_labels)
    print(f"   📈 Logistic Regression: {lr_accuracy:.4f}")
    
    # Random Forest
    rf_pred = ensemble.rf_model.predict(X_test)
    rf_pred_labels = ensemble.label_encoder.inverse_transform(rf_pred)
    rf_accuracy = accuracy_score(y_test, rf_pred_labels)
    print(f"   🌲 Random Forest: {rf_accuracy:.4f}")
    
    # Naive Bayes
    nb_pred = ensemble.nb_model.predict(X_test_scaled)
    nb_pred_labels = ensemble.label_encoder.inverse_transform(nb_pred)
    nb_accuracy = accuracy_score(y_test, nb_pred_labels)
    print(f"   🎯 Naive Bayes: {nb_accuracy:.4f}")
    
    # Ensemble performance
    ensemble_pred = ensemble.predict(X_test)
    ensemble_accuracy = accuracy_score(y_test, ensemble_pred)
    
    print(f"\n🔥 ENSEMBLE MODEL: {ensemble_accuracy:.4f}")
    
    # Confusion Matrix
    print("\n📊 CONFUSION MATRIX:")
    cm = confusion_matrix(y_test, ensemble_pred, labels=ensemble.classes_)
    cm_df = pd.DataFrame(cm, index=ensemble.classes_, columns=ensemble.classes_)
    print(cm_df)
    
    # Detailed classification report
    print("\n📋 DETAILED CLASSIFICATION REPORT:")
    print(classification_report(y_test, ensemble_pred, target_names=ensemble.classes_))
    
    # Feature importance from Random Forest
    if hasattr(ensemble.rf_model, 'feature_importances_'):
        print("\n🔍 RANDOM FOREST FEATURE IMPORTANCE (Top 10):")
        feature_importance = pd.DataFrame({
            'feature': feature_names,
            'importance': ensemble.rf_model.feature_importances_
        }).sort_values('importance', ascending=False)
        
        for i, (_, row) in enumerate(feature_importance.head(10).iterrows()):
            print(f"   {i+1}. {row['feature']}: {row['importance']:.4f}")
    
    # Logistic Regression coefficients (absolute values, top 10)
    if hasattr(ensemble.lr_model, 'coef_'):
        print("\n📈 LOGISTIC REGRESSION COEFFICIENTS (Top 10 by absolute magnitude):")
        # Average coefficients across classes
        coef_avg = np.abs(ensemble.lr_model.coef_).mean(axis=0)
        coef_df = pd.DataFrame({
            'feature': feature_names,
            'abs_coefficient': coef_avg
        }).sort_values('abs_coefficient', ascending=False)
        
        for i, (_, row) in enumerate(coef_df.head(10).iterrows()):
            print(f"   {i+1}. {row['feature']}: {row['abs_coefficient']:.4f}")
    
    return ensemble_accuracy

def save_training_artifacts(ensemble, feature_names):
    """
    Save all trained models and artifacts
    """
    models_dir = "models"
    os.makedirs(models_dir, exist_ok=True)
    
    # Save individual models
    with open(os.path.join(models_dir, "logistic_regression.pkl"), 'wb') as f:
        pickle.dump(ensemble.lr_model, f)
    
    with open(os.path.join(models_dir, "random_forest.pkl"), 'wb') as f:
        pickle.dump(ensemble.rf_model, f)
    
    with open(os.path.join(models_dir, "naive_bayes.pkl"), 'wb') as f:
        pickle.dump(ensemble.nb_model, f)
    
    # Save ensemble model
    with open(os.path.join(models_dir, "ensemble_model.pkl"), 'wb') as f:
        pickle.dump(ensemble, f)
    
    # Save scaler and feature names
    with open(os.path.join(models_dir, "scaler.pkl"), 'wb') as f:
        pickle.dump(ensemble.scaler, f)
    
    with open(os.path.join(models_dir, "feature_names.pkl"), 'wb') as f:
        pickle.dump(feature_names, f)
    
    with open(os.path.join(models_dir, "label_encoder.pkl"), 'wb') as f:
        pickle.dump(ensemble.label_encoder, f)
    
    # Save learned model weights for insight_engine to load
    with open(os.path.join(models_dir, "model_weights.pkl"), 'wb') as f:
        pickle.dump(ensemble.model_weights, f)
    
    print(f"💾 All model artifacts saved successfully!")
    print(f"   Model weights: LR={ensemble.model_weights[0]:.3f}, RF={ensemble.model_weights[1]:.3f}, NB={ensemble.model_weights[2]:.3f}")

def train_ensemble_model():
    """
    Main training function for the ensemble model.
    Now includes 5-fold stratified cross-validation and learned weights.
    """
    print("🚀 STARTING ENSEMBLE MODEL TRAINING")
    print("="*60)
    
    try:
        # Load and preprocess data (uses PREDICTIVE features, no leakage)
        X, y, feature_names, df = load_and_preprocess_data()
        
        # --- 5-fold Stratified Cross-Validation ---
        print("\n" + "="*50)
        print("📊 5-FOLD STRATIFIED CROSS-VALIDATION")
        print("="*50)
        
        le_cv = LabelEncoder()
        y_encoded_cv = le_cv.fit_transform(y)
        skf = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
        
        cv_scores = []
        for fold, (train_idx, val_idx) in enumerate(skf.split(X, y_encoded_cv), 1):
            X_fold_train, X_fold_val = X[train_idx], X[val_idx]
            y_fold_train, y_fold_val = y[train_idx], y[val_idx]
            
            fold_ensemble = EnsembleModel()
            fold_ensemble.fit(X_fold_train, y_fold_train, feature_names=feature_names)
            fold_pred = fold_ensemble.predict(X_fold_val)
            fold_acc = accuracy_score(y_fold_val, fold_pred)
            cv_scores.append(fold_acc)
            print(f"   Fold {fold}: {fold_acc:.4f}")
        
        cv_mean = np.mean(cv_scores)
        cv_std = np.std(cv_scores)
        print(f"\n   📈 CV Accuracy: {cv_mean:.4f} ± {cv_std:.4f}")
        
        # --- Final training on 80/20 split ---
        print("\n" + "="*50)
        print("🔄 FINAL MODEL TRAINING (80/20 holdout)")
        print("="*50)
        
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42, stratify=y
        )
        
        print(f"\n📊 DATA SPLIT:")
        print(f"   Training samples: {X_train.shape[0]}")
        print(f"   Testing samples: {X_test.shape[0]}")
        print(f"   Features: {X_train.shape[1]}")
        
        # Train ensemble model (weights learned automatically)
        ensemble = EnsembleModel()
        ensemble.fit(X_train, y_train, feature_names=feature_names)
        
        # Evaluate model
        accuracy = evaluate_model(ensemble, X_test, y_test, feature_names)
        
        # Save models
        save_training_artifacts(ensemble, feature_names)
        
        # Test with sample predictions
        print("\n🧪 SAMPLE PREDICTIONS:")
        
        # Create sample data based on actual feature ranges
        sample_data = []
        for i in range(3):
            sample = {}
            for j, feature in enumerate(feature_names):
                feature_min = X_train[:, j].min()
                feature_max = X_train[:, j].max()
                feature_mean = X_train[:, j].mean()
                
                # Create low, medium, high samples
                if i == 0:  # Low performance
                    value = feature_min + (feature_mean - feature_min) * 0.3
                elif i == 1:  # Medium performance
                    value = feature_mean
                else:  # High performance
                    value = feature_mean + (feature_max - feature_mean) * 0.7
                
                sample[feature] = round(float(value), 1)
            sample_data.append(sample)
        
        for i, sample in enumerate(sample_data, 1):
            result = ensemble.predict_single(sample)
            print(f"   Sample {i}: {sample}")
            print(f"   → Prediction: {result['prediction']} (Confidence: {result['confidence']:.1%})")
            print()
        
        print(f"\n✅ TRAINING COMPLETED SUCCESSFULLY!")
        print(f"📊 Cross-Validation Accuracy: {cv_mean:.4f} ± {cv_std:.4f}")
        print(f"🎯 Final Holdout Accuracy: {accuracy:.4f}")
        
        return ensemble
        
    except Exception as e:
        print(f"❌ ERROR during training: {e}")
        import traceback
        traceback.print_exc()
        return None

if __name__ == "__main__":
    # Train the model
    trained_ensemble = train_ensemble_model()
    
    if trained_ensemble:
        print("\n🎉 Ensemble model is ready for use!")
        print("📁 Models saved in 'models/' directory")
        print("🔮 You can now use the model for predictions")
        print("\n💡 Next steps:")
        print("   1. Run 'python scripts/predict_test.py' to test predictions")
        print("   2. Use the model in your Insight Engine")
        print("   3. Integrate with your chatbot system")
    else:
        print("\n💥 Training failed. Please check your data file and try again.")