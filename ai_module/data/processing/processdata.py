# data/preprocessing/preprocess_data.py

import pandas as pd
import numpy as np
import os
import sys
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.impute import SimpleImputer
import warnings
warnings.filterwarnings('ignore')

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

class OJTDataPreprocessor:
    """
    Comprehensive data preprocessor for OJT grading data
    Handles missing values, feature engineering, scaling, and data validation
    """
    
    def __init__(self):
        self.scaler = StandardScaler()
        self.label_encoder = LabelEncoder()
        self.imputer = SimpleImputer(strategy='mean')
        self.feature_names = None
        self.target_column = None
        self.is_fitted = False
        
    def load_data(self, data_path="data/datasets/ojt_grading_data.csv"):
        """
        Load dataset from CSV file
        
        Args:
            data_path (str): Path to the CSV file
            
        Returns:
            pd.DataFrame: Loaded dataset
        """
        if not os.path.exists(data_path):
            raise FileNotFoundError(f"❌ Dataset not found at {data_path}")
        
        print("📁 Loading dataset...")
        df = pd.read_csv(data_path)
        
        print(f"📊 Original dataset shape: {df.shape}")
        print(f"📋 Columns: {list(df.columns)}")
        
        return df
    
    def detect_feature_columns(self, df):
        """
        Automatically detect feature columns in the dataset
        """
        # Common OJT feature names
        common_features = [
            'weekly_progress', 'progress', 'weekly_score', 'weekly',
            'narrative_report', 'narrative', 'report_score', 'report',
            'coordinator_evaluation', 'coordinator_score', 'coordinator', 'coordinator_eval',
            'partner_evaluation', 'partner_score', 'partner', 'partner_eval',
            'attendance', 'performance', 'evaluation', 'score', 'rating'
        ]
        
        # Exclude common target columns
        exclude_columns = [
            'performance_category', 'target', 'label', 'class', 
            'grade', 'result', 'status', 'final_grade', 'outcome'
        ]
        
        # Find numeric columns that could be features
        numeric_columns = df.select_dtypes(include=[np.number]).columns.tolist()
        
        # Also consider string columns that can be converted to scores
        potential_columns = []
        for col in df.columns:
            if col.lower() in exclude_columns:
                continue
            
            # Check if column name matches common feature patterns
            col_lower = col.lower()
            if any(feat in col_lower for feat in common_features):
                potential_columns.append(col)
            elif df[col].dtype in ['object', 'category']:
                # Check if it's a categorical score (e.g., "Excellent", "Good", "Poor")
                unique_vals = df[col].dropna().unique()
                if len(unique_vals) <= 10:  # Reasonable number of categories
                    potential_columns.append(col)
        
        # If no features detected, use all numeric columns (except obvious targets)
        if not potential_columns:
            potential_columns = [col for col in numeric_columns 
                              if not any(exclude in col.lower() for exclude in exclude_columns)]
        
        # Remove duplicates and return
        feature_columns = list(dict.fromkeys(potential_columns))
        
        print(f"🔍 Detected {len(feature_columns)} feature columns: {feature_columns}")
        return feature_columns
    
    def detect_target_column(self, df):
        """
        Automatically detect target column in the dataset
        """
        # Common target column names (priority order)
        target_priority = [
            'performance_category', 'category', 'performance', 
            'target', 'label', 'class', 'grade', 'result', 'status',
            'final_grade', 'outcome', 'verdict'
        ]
        
        # First, check for exact matches
        for candidate in target_priority:
            if candidate in df.columns:
                return candidate
        
        # Then check for partial matches
        for col in df.columns:
            col_lower = col.lower()
            if any(target in col_lower for target in target_priority):
                return col
        
        # If no target found, try to find categorical columns
        categorical_columns = df.select_dtypes(include=['object', 'category']).columns
        
        if len(categorical_columns) == 1:
            return categorical_columns[0]
        
        # If multiple categorical, look for performance-related ones
        performance_keywords = ['performance', 'grade', 'result', 'category', 'status']
        for col in categorical_columns:
            if any(keyword in col.lower() for keyword in performance_keywords):
                return col
        
        # Last resort: use the last column
        if len(categorical_columns) > 0:
            return categorical_columns[-1]
        
        raise ValueError("❌ Could not automatically detect target column")
    
    def handle_missing_values(self, df, feature_columns, target_column):
        """
        Handle missing values in features and target
        """
        print("\n🔧 Handling missing values...")
        
        # Check for missing values
        missing_features = df[feature_columns].isnull().sum()
        missing_target = df[target_column].isnull().sum()
        
        if missing_features.sum() > 0:
            print(f"⚠️  Missing values in features: {missing_features[missing_features > 0].to_dict()}")
            
            # Use mean imputation for numeric features
            for col in feature_columns:
                if df[col].isnull().sum() > 0:
                    if df[col].dtype in [np.number]:
                        imputer = SimpleImputer(strategy='mean')
                        df[col] = imputer.fit_transform(df[[col]]).ravel()
                        print(f"   ✅ Filled missing values in {col} with mean: {imputer.statistics_[0]:.2f}")
                    else:
                        # For categorical features, use mode
                        mode_val = df[col].mode()[0] if not df[col].mode().empty else 'Unknown'
                        df[col].fillna(mode_val, inplace=True)
                        print(f"   ✅ Filled missing values in {col} with mode: {mode_val}")
        
        if missing_target > 0:
            print(f"⚠️  Missing values in target: {missing_target}")
            print("   🗑️  Dropping rows with missing target values...")
            df = df.dropna(subset=[target_column])
            print(f"   ✅ Remaining samples: {len(df)}")
        
        return df
    
    def convert_categorical_features(self, df, feature_columns):
        """
        Convert categorical features to numerical scores
        """
        print("\n🔄 Converting categorical features to numerical scores...")
        
        categorical_mapping = {}
        
        for col in feature_columns:
            if df[col].dtype in ['object', 'category']:
                unique_vals = df[col].dropna().unique()
                print(f"   📊 {col}: {list(unique_vals)}")
                
                # Common performance category mappings
                common_mappings = {
                    # Performance scales
                    'excellent': 90, 'outstanding': 95, 'superb': 92,
                    'very good': 85, 'good': 80, 'satisfactory': 75,
                    'fair': 70, 'average': 75, 'needs improvement': 65,
                    'poor': 60, 'unsatisfactory': 55, 'fail': 50,
                    
                    # Letter grades
                    'a+': 97, 'a': 93, 'a-': 90,
                    'b+': 87, 'b': 83, 'b-': 80,
                    'c+': 77, 'c': 73, 'c-': 70,
                    'd+': 67, 'd': 63, 'd-': 60,
                    'f': 50,
                    
                    # Numeric scales as strings
                    '1': 20, '2': 40, '3': 60, '4': 80, '5': 100,
                    'low': 40, 'medium': 70, 'high': 90
                }
                
                # Create mapping for this column
                col_mapping = {}
                for val in unique_vals:
                    val_lower = str(val).lower().strip()
                    
                    if val_lower in common_mappings:
                        col_mapping[val] = common_mappings[val_lower]
                    elif val_lower.replace('.', '').isdigit():
                        # Already numeric string
                        col_mapping[val] = float(val)
                    else:
                        # Default: map to ordinal position
                        col_mapping[val] = list(unique_vals).index(val) * (100 / max(1, len(unique_vals)-1))
                
                # Apply mapping
                df[col] = df[col].map(col_mapping)
                categorical_mapping[col] = col_mapping
                print(f"   ✅ Converted {col} to numerical scores")
        
        return df, categorical_mapping
    
    def engineer_features(self, df, feature_columns):
        """
        Create new engineered features from existing ones
        """
        print("\n⚙️ Engineering new features...")
        
        original_features = feature_columns.copy()
        new_features = []
        
        # 1. Overall average score
        if len(feature_columns) >= 2:
            df['overall_average'] = df[feature_columns].mean(axis=1)
            new_features.append('overall_average')
            print("   ✅ Created 'overall_average' feature")
        
        # 2. Performance consistency (standard deviation)
        if len(feature_columns) >= 2:
            df['performance_consistency'] = df[feature_columns].std(axis=1)
            # Lower std = more consistent performance
            new_features.append('performance_consistency')
            print("   ✅ Created 'performance_consistency' feature")
        
        # 3. Progress vs Evaluation ratio
        progress_cols = [col for col in feature_columns if 'progress' in col.lower()]
        eval_cols = [col for col in feature_columns if 'eval' in col.lower() or 'evaluation' in col.lower()]
        
        if progress_cols and eval_cols:
            progress_mean = df[progress_cols].mean(axis=1)
            eval_mean = df[eval_cols].mean(axis=1)
            df['progress_eval_ratio'] = progress_mean / (eval_mean + 1e-8)  # Avoid division by zero
            new_features.append('progress_eval_ratio')
            print("   ✅ Created 'progress_eval_ratio' feature")
        
        # 4. Minimum and Maximum scores
        if len(feature_columns) >= 2:
            df['min_score'] = df[feature_columns].min(axis=1)
            df['max_score'] = df[feature_columns].max(axis=1)
            new_features.extend(['min_score', 'max_score'])
            print("   ✅ Created 'min_score' and 'max_score' features")
        
        # 5. Score range (variability)
        if 'min_score' in df.columns and 'max_score' in df.columns:
            df['score_range'] = df['max_score'] - df['min_score']
            new_features.append('score_range')
            print("   ✅ Created 'score_range' feature")
        
        # Update feature columns list
        all_features = original_features + new_features
        
        return df, all_features
    
    def validate_data(self, df, feature_columns, target_column):
        """
        Validate the preprocessed data
        """
        print("\n🔍 Validating preprocessed data...")
        
        # Check for infinite values
        inf_count = np.isinf(df[feature_columns]).sum().sum()
        if inf_count > 0:
            print(f"⚠️  Found {inf_count} infinite values. Replacing with bounds...")
            for col in feature_columns:
                df[col] = df[col].replace([np.inf, -np.inf], np.nan)
                df[col] = df[col].fillna(df[col].mean())
        
        # Check for negative scores (if scores should be 0-100)
        negative_scores = (df[feature_columns] < 0).sum().sum()
        if negative_scores > 0:
            print(f"⚠️  Found {negative_scores} negative scores. Clipping to 0...")
            for col in feature_columns:
                df[col] = df[col].clip(lower=0)
        
        # Check for unrealistic high scores
        high_scores = (df[feature_columns] > 100).sum().sum()
        if high_scores > 0:
            print(f"⚠️  Found {high_scores} scores > 100. Clipping to 100...")
            for col in feature_columns:
                df[col] = df[col].clip(upper=100)
        
        # Check target distribution
        target_distribution = df[target_column].value_counts()
        print(f"🎯 Final target distribution:")
        for category, count in target_distribution.items():
            percentage = (count / len(df)) * 100
            print(f"   {category}: {count} ({percentage:.1f}%)")
        
        # Check feature statistics
        print(f"\n📈 Final feature statistics:")
        for col in feature_columns:
            print(f"   {col}: min={df[col].min():.1f}, max={df[col].max():.1f}, "
                  f"mean={df[col].mean():.1f}, std={df[col].std():.1f}")
        
        return df
    
    def fit(self, df, feature_columns=None, target_column=None):
        """
        Fit the preprocessor on training data
        """
        print("🚀 FITTING DATA PREPROCESSOR")
        print("="*50)
        
        # Detect features and target if not provided
        if feature_columns is None:
            feature_columns = self.detect_feature_columns(df)
        
        if target_column is None:
            target_column = self.detect_target_column(df)
        
        self.feature_names = feature_columns
        self.target_column = target_column
        
        print(f"🎯 Target column: {target_column}")
        print(f"🔧 Feature columns: {feature_columns}")
        
        # Handle missing values
        df_clean = self.handle_missing_values(df, feature_columns, target_column)
        
        # Convert categorical features to numerical
        df_numeric, categorical_mapping = self.convert_categorical_features(df_clean, feature_columns)
        
        # Engineer new features
        df_engineered, all_features = self.engineer_features(df_numeric, feature_columns)
        
        # Validate data
        df_final = self.validate_data(df_engineered, all_features, target_column)
        
        # Fit scaler on features only
        X = df_final[all_features].values
        self.scaler.fit(X)
        
        # Fit label encoder on target
        y = df_final[target_column].values
        self.label_encoder.fit(y)
        
        self.is_fitted = True
        
        print("✅ Preprocessor fitting completed!")
        
        return df_final, all_features, target_column, categorical_mapping
    
    def transform(self, df, feature_columns=None):
        """
        Transform new data using fitted preprocessor
        """
        if not self.is_fitted:
            raise ValueError("❌ Preprocessor must be fitted before transformation")
        
        if feature_columns is None:
            feature_columns = self.feature_names
        
        print("🔄 Transforming data...")
        
        # Handle missing values
        df_clean = self.handle_missing_values(df, feature_columns, self.target_column)
        
        # Convert categorical features (using same mapping as fit)
        df_numeric, _ = self.convert_categorical_features(df_clean, feature_columns)
        
        # Engineer features
        df_engineered, all_features = self.engineer_features(df_numeric, feature_columns)
        
        # Apply scaling
        X = df_engineered[all_features].values
        X_scaled = self.scaler.transform(X)
        
        # Prepare target
        if self.target_column in df_engineered.columns:
            y = df_engineered[self.target_column].values
            try:
                y_encoded = self.label_encoder.transform(y)
            except ValueError:
                # Handle unseen labels in target
                print("⚠️  Unknown labels in target, using original values")
                y_encoded = y
        else:
            y_encoded = None
        
        print(f"✅ Data transformation completed: {X_scaled.shape}")
        
        return X_scaled, y_encoded if y_encoded is not None else None, all_features
    
    def fit_transform(self, df, feature_columns=None, target_column=None):
        """
        Fit and transform in one step
        """
        df_processed, feature_columns, target_column, categorical_mapping = self.fit(
            df, feature_columns, target_column
        )
        
        X, y, feature_columns = self.transform(df_processed, feature_columns)
        
        return X, y, feature_columns, target_column, categorical_mapping

def load_and_preprocess_data(data_path="data/datasets/ojt_grading_data.csv"):
    """
    Main function to load and preprocess data
    """
    try:
        # Initialize preprocessor
        preprocessor = OJTDataPreprocessor()
        
        # Load data
        df = preprocessor.load_data(data_path)
        
        # Fit and transform data
        X, y, feature_names, target_name, categorical_mapping = preprocessor.fit_transform(df)
        
        print(f"\n🎉 PREPROCESSING COMPLETED SUCCESSFULLY!")
        print(f"📊 Final dataset shape: {X.shape}")
        print(f"🎯 Target variable: {target_name}")
        print(f"🔧 Features used: {feature_names}")
        
        return X, y, feature_names, df
        
    except Exception as e:
        print(f"❌ Error in preprocessing: {e}")
        raise

def save_preprocessor(preprocessor, filepath="models/preprocessor.pkl"):
    """
    Save fitted preprocessor for later use
    """
    import pickle
    import os
    
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    
    with open(filepath, 'wb') as f:
        pickle.dump(preprocessor, f)
    
    print(f"💾 Preprocessor saved to: {filepath}")

def load_preprocessor(filepath="models/preprocessor.pkl"):
    """
    Load fitted preprocessor
    """
    import pickle
    
    with open(filepath, 'rb') as f:
        preprocessor = pickle.load(f)
    
    print(f"📁 Preprocessor loaded from: {filepath}")
    return preprocessor

if __name__ == "__main__":
    # Test the preprocessor
    try:
        X, y, feature_names, df = load_and_preprocess_data()
        
        print("\n🧪 PREPROCESSING TEST SUCCESSFUL!")
        print(f"✅ Features shape: {X.shape}")
        print(f"✅ Target shape: {y.shape if y is not None else 'None'}")
        print(f"✅ Feature names: {feature_names}")
        
    except Exception as e:
        print(f"❌ Preprocessing test failed: {e}")