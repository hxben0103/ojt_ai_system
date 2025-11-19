# scripts/train_model.py

import pandas as pd
import numpy as np
import pickle
import os
import sys
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import RandomForestClassifier
from sklearn.naive_bayes import GaussianNB
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
import warnings
warnings.filterwarnings('ignore')

# Add parent directory to path to import modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

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
        
    def fit(self, X, y, feature_names=None, lr_weight=0.3, rf_weight=0.5, nb_weight=0.2):
        """
        Train all three models and set their weights
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
        
        # Set model weights
        self.model_weights = np.array([lr_weight, rf_weight, nb_weight])
        print(f"⚖️ Model weights - LR: {lr_weight}, RF: {rf_weight}, NB: {nb_weight}")
        
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

def detect_feature_columns(df):
    """
    Automatically detect feature columns in the dataset
    """
    # Common OJT feature names (you can extend this list)
    common_features = [
        'weekly_progress', 'progress', 'weekly_score',
        'narrative_report', 'narrative', 'report_score', 
        'coordinator_evaluation', 'coordinator_score', 'coordinator',
        'partner_evaluation', 'partner_score', 'partner',
        'attendance', 'performance', 'evaluation'
    ]
    
    # Exclude common target columns
    exclude_columns = ['performance_category', 'target', 'label', 'class', 'grade', 'result', 'status']
    
    # Find numeric columns that could be features
    numeric_columns = df.select_dtypes(include=[np.number]).columns.tolist()
    
    # Filter out target-like columns and keep feature-like columns
    feature_columns = []
    for col in numeric_columns:
        col_lower = col.lower()
        # Include if it matches common feature patterns and not in exclude list
        if (any(feat in col_lower for feat in common_features) and 
            not any(exclude in col_lower for exclude in exclude_columns)):
            feature_columns.append(col)
    
    # If no features detected, use all numeric columns (except obvious targets)
    if not feature_columns:
        feature_columns = [col for col in numeric_columns 
                          if not any(exclude in col.lower() for exclude in exclude_columns)]
    
    # If still no features, use first 4 numeric columns
    if not feature_columns and len(numeric_columns) >= 4:
        feature_columns = numeric_columns[:4]
    
    return feature_columns

def detect_target_column(df):
    """
    Automatically detect target column in the dataset
    """
    # Common target column names
    target_candidates = [
        'performance_category', 'category', 'performance', 
        'target', 'label', 'class', 'grade', 'result', 'status'
    ]
    
    # First, check for exact matches
    for candidate in target_candidates:
        if candidate in df.columns:
            return candidate
    
    # Then check for partial matches
    for col in df.columns:
        col_lower = col.lower()
        if any(target in col_lower for target in target_candidates):
            return col
    
    # If no target found, try to find categorical columns
    categorical_columns = df.select_dtypes(include=['object', 'category']).columns
    if len(categorical_columns) == 1:
        return categorical_columns[0]
    
    # If multiple categorical, return the first one
    if len(categorical_columns) > 0:
        return categorical_columns[0]
    
    # Last resort: use the last column
    return df.columns[-1]

def load_and_preprocess_data():
    """
    Load and preprocess the OJT grading data from CSV
    Automatically detect features and target
    """
    data_path = "data/datasets/ojt_grading_data.csv"
    
    if not os.path.exists(data_path):
        raise FileNotFoundError(f"❌ Dataset not found at {data_path}")
    
    print("📁 Loading dataset...")
    df = pd.read_csv(data_path)
    
    print(f"📊 Dataset shape: {df.shape}")
    print(f"📋 All columns: {list(df.columns)}")
    
    # Automatically detect features and target
    feature_columns = detect_feature_columns(df)
    target_column = detect_target_column(df)
    
    print(f"🔍 Auto-detected features: {feature_columns}")
    print(f"🎯 Auto-detected target: {target_column}")
    
    # Validate we have features and target
    if not feature_columns:
        raise ValueError("❌ Could not detect feature columns in the dataset")
    
    if target_column not in df.columns:
        raise ValueError(f"❌ Target column '{target_column}' not found in dataset")
    
    # Handle missing values in features
    missing_count = df[feature_columns].isnull().sum().sum()
    if missing_count > 0:
        print(f"⚠️  Found {missing_count} missing values in features. Filling with mean...")
        df[feature_columns] = df[feature_columns].fillna(df[feature_columns].mean())
    
    # Handle missing values in target
    if df[target_column].isnull().sum() > 0:
        print(f"⚠️  Found missing values in target. Dropping rows with missing target...")
        df = df.dropna(subset=[target_column])
    
    X = df[feature_columns].values
    y = df[target_column].values
    
    print(f"\n🎯 Target distribution:")
    target_counts = pd.Series(y).value_counts()
    for category, count in target_counts.items():
        print(f"   {category}: {count} ({count/len(y)*100:.1f}%)")
    
    print(f"\n📈 Feature statistics:")
    for i, feature in enumerate(feature_columns):
        print(f"   {feature}: min={X[:, i].min():.1f}, max={X[:, i].max():.1f}, mean={X[:, i].mean():.1f}")
    
    return X, y, feature_columns, df

def evaluate_model(ensemble, X_test, y_test, feature_names):
    """
    Comprehensive evaluation of the ensemble model
    """
    print("\n" + "="*50)
    print("🎯 MODEL EVALUATION")
    print("="*50)
    
    # Individual model evaluations
    X_test_scaled = ensemble.scaler.transform(X_test)
    
    print("\n📊 INDIVIDUAL MODEL PERFORMANCE:")
    
    # Logistic Regression
    lr_pred = ensemble.lr_model.predict(X_test_scaled)
    lr_accuracy = accuracy_score(y_test, ensemble.label_encoder.inverse_transform(lr_pred))
    print(f"   📈 Logistic Regression: {lr_accuracy:.4f}")
    
    # Random Forest
    rf_pred = ensemble.rf_model.predict(X_test)
    rf_accuracy = accuracy_score(y_test, ensemble.label_encoder.inverse_transform(rf_pred))
    print(f"   🌲 Random Forest: {rf_accuracy:.4f}")
    
    # Naive Bayes
    nb_pred = ensemble.nb_model.predict(X_test_scaled)
    nb_accuracy = accuracy_score(y_test, ensemble.label_encoder.inverse_transform(nb_pred))
    print(f"   🎯 Naive Bayes: {nb_accuracy:.4f}")
    
    # Ensemble performance
    ensemble_pred = ensemble.predict(X_test)
    ensemble_accuracy = accuracy_score(y_test, ensemble_pred)
    
    print(f"\n🔥 ENSEMBLE MODEL: {ensemble_accuracy:.4f}")
    
    # Detailed classification report
    print("\n📋 DETAILED CLASSIFICATION REPORT:")
    print(classification_report(y_test, ensemble_pred, target_names=ensemble.classes_))
    
    # Feature importance from Random Forest
    if hasattr(ensemble.rf_model, 'feature_importances_'):
        print("\n🔍 RANDOM FOREST FEATURE IMPORTANCE:")
        feature_importance = pd.DataFrame({
            'feature': feature_names,
            'importance': ensemble.rf_model.feature_importances_
        }).sort_values('importance', ascending=False)
        
        for _, row in feature_importance.iterrows():
            print(f"   {row['feature']}: {row['importance']:.4f}")
    
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
    
    print("💾 All model artifacts saved successfully!")

def train_ensemble_model():
    """
    Main training function for the ensemble model
    """
    print("🚀 STARTING ENSEMBLE MODEL TRAINING")
    print("="*60)
    
    try:
        # Load and preprocess data
        X, y, feature_names, df = load_and_preprocess_data()
        
        # Split data
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=0.2, random_state=42, stratify=y
        )
        
        print(f"\n📊 DATA SPLIT:")
        print(f"   Training samples: {X_train.shape[0]}")
        print(f"   Testing samples: {X_test.shape[0]}")
        print(f"   Features: {X_train.shape[1]}")
        
        # Train ensemble model
        print("\n🔄 TRAINING ENSEMBLE MODEL...")
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
        print(f"🎯 Final Ensemble Accuracy: {accuracy:.4f}")
        
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