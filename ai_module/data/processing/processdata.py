# data/processing/processdata.py
#
# OJT Data Preprocessor
# Handles loading, mapping, and preprocessing of OJT grading data
# Ensures consistency with FEATURE_COLUMNS used in training and inference

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

# Standard FEATURE_COLUMNS - must match exactly with train_model.py and insight_engine.py
FEATURE_COLUMNS = [
    "total_hours_completed",
    "required_hours",
    "attendance_rate",
    "late_count",
    "absent_count",
    "hours_completed_ratio",
    "total_tasks_logged",
    "total_task_hours",
    "number_of_distinct_competencies",
    "hours_software_development",
    "hours_machine_learning_engineering",
    "hours_it_related_research",
    "hours_ux_ui_design",
    "hours_information_security_analysis",
    "hours_networking",
    "hours_technical_support",
    "hours_data_analysis",
    "hours_customer_service",
    "hours_data_entry_management",
    "hours_office_work",
    "weekly_progress_grade",
    "narrative_report_grade",
    "coordinator_eval_grade",
    "supervisor_eval_grade",
    "has_weekly_progress_grade",
    "has_narrative_report_grade",
    "has_coordinator_eval_grade",
    "has_supervisor_eval_grade",
    "total_chatbot_queries",
    "chatbot_queries_last_30_days"
]

# Predictive features — excludes grading components that are used to derive
# the target variable (risk_level).  Using them as features creates data
# leakage because final_ojt_grade = 0.20*WPR + 0.20*NR + 0.20*CE + 0.40*SE,
# which is the same formula used to compute risk_level.
PREDICTIVE_FEATURE_COLUMNS = [
    col for col in FEATURE_COLUMNS
    if col not in {
        "weekly_progress_grade",
        "narrative_report_grade",
        "coordinator_eval_grade",
        "supervisor_eval_grade",
        "has_weekly_progress_grade",
        "has_narrative_report_grade",
        "has_coordinator_eval_grade",
        "has_supervisor_eval_grade",
    }
]

# OJT Grading Component Weights (as per institutional requirements)
WPR_WEIGHT = 0.20  # Weekly Progress Report
NR_WEIGHT = 0.20   # Narrative Report
CE_WEIGHT = 0.20   # Coordinator Evaluation
SE_WEIGHT = 0.40   # Supervisor Evaluation

def classify_risk(grade: float) -> str:
    """
    Classify risk level based on final OJT grade.
    
    HIGH: grade < 75
    MEDIUM: 75 <= grade < 85
    LOW: grade >= 85
    """
    if grade < 75:
        return "HIGH"
    elif grade < 85:
        return "MEDIUM"
    else:
        return "LOW"

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
    
    def map_grading_components(self, df):
        """
        Map dataset columns to grading components using flexible matching.
        
        Maps:
        - WPR (Weekly Progress Report): weekly_progress, weekly_score, progress, etc.
        - NR (Narrative Report): narrative_report, narrative_score, etc.
        - CE (Coordinator Evaluation): coordinator_eval, coordinator_evaluation, etc.
        - SE (Supervisor Evaluation): supervisor_eval, partner_evaluation, industry_partner_eval, etc.
        
        Args:
            df: DataFrame with original columns
            
        Returns:
            dict: Mapping of component names to column names found in dataset
        """
        mapping = {
            'WPR': None,
            'NR': None,
            'CE': None,
            'SE': None
        }

        def column_matches(col_lower, include_tokens):
            return all(token in col_lower for token in include_tokens)

        # Explicit column names override everything
        explicit_names = {
            'weekly_progress_grade': 'WPR',
            'narrative_report_grade': 'NR',
            'coordinator_eval_grade': 'CE',
            'supervisor_eval_grade': 'SE'
        }
        for explicit_col, component in explicit_names.items():
            if explicit_col in df.columns:
                mapping[component] = explicit_col

        # If any components are still missing, try flexible matching
        for col in df.columns:
            col_lower = col.lower()

            if mapping['WPR'] is None:
                if column_matches(col_lower, ['weekly', 'progress']) or column_matches(col_lower, ['weekly', 'report']):
                    if 'score' in col_lower or 'grade' in col_lower:
                        mapping['WPR'] = col
                        continue

            if mapping['NR'] is None:
                if column_matches(col_lower, ['narrative', 'report']) or 'narrative' in col_lower:
                    if 'score' in col_lower or 'grade' in col_lower:
                        mapping['NR'] = col
                        continue

            if mapping['CE'] is None:
                if 'coordinator' in col_lower or 'coord' in col_lower:
                    if 'eval' in col_lower or 'score' in col_lower or 'grade' in col_lower:
                        mapping['CE'] = col
                        continue

            if mapping['SE'] is None:
                if 'supervisor' in col_lower or 'partner' in col_lower or 'industry' in col_lower:
                    if 'eval' in col_lower or 'score' in col_lower or 'grade' in col_lower:
                        mapping['SE'] = col
                        continue
        
        print(f"\n📊 Grading Component Mapping:")
        print(f"   WPR (20%): {mapping['WPR'] or 'NOT FOUND'}")
        print(f"   NR (20%): {mapping['NR'] or 'NOT FOUND'}")
        print(f"   CE (20%): {mapping['CE'] or 'NOT FOUND'}")
        print(f"   SE (40%): {mapping['SE'] or 'NOT FOUND'}")
        
        # Check if all required components are found
        missing = [k for k, v in mapping.items() if v is None]
        if missing:
            print(f"⚠️  Warning: Missing grading components: {missing}")
            print("   Will use 0.0 for missing components")
        
        return mapping
    
    def compute_final_grade_and_risk(self, df, grading_mapping):
        """
        Compute final OJT grade and risk level using institutional grading weights.
        
        Formula: final_ojt_grade = 0.20 * WPR + 0.20 * NR + 0.20 * CE + 0.40 * SE
        
        Args:
            df: DataFrame with grading component columns
            grading_mapping: Dict mapping component names to column names
            
        Returns:
            DataFrame with added 'final_ojt_grade' and 'risk_level' columns
        """
        print("\n📊 Computing final OJT grade and risk level...")
        
        # Extract component values
        wpr_col = grading_mapping.get('WPR')
        nr_col = grading_mapping.get('NR')
        ce_col = grading_mapping.get('CE')
        se_col = grading_mapping.get('SE')
        
        # Compute final grade for each row
        final_grades = []
        for idx, row in df.iterrows():
            wpr = float(row[wpr_col]) if wpr_col and pd.notna(row.get(wpr_col, np.nan)) else 0.0
            nr = float(row[nr_col]) if nr_col and pd.notna(row.get(nr_col, np.nan)) else 0.0
            ce = float(row[ce_col]) if ce_col and pd.notna(row.get(ce_col, np.nan)) else 0.0
            se = float(row[se_col]) if se_col and pd.notna(row.get(se_col, np.nan)) else 0.0
            
            # Compute weighted final grade
            final_grade = (wpr * WPR_WEIGHT + 
                          nr * NR_WEIGHT + 
                          ce * CE_WEIGHT + 
                          se * SE_WEIGHT)
            
            final_grades.append(final_grade)
        
        df['final_ojt_grade'] = final_grades
        df['risk_level'] = df['final_ojt_grade'].apply(classify_risk)
        
        print(f"✅ Computed final grades and risk levels")
        print(f"   Final grade range: {df['final_ojt_grade'].min():.1f} - {df['final_ojt_grade'].max():.1f}")
        print(f"   Risk distribution:")
        risk_counts = df['risk_level'].value_counts()
        for risk, count in risk_counts.items():
            print(f"      {risk}: {count} ({count/len(df)*100:.1f}%)")
        
        return df
    
    def ensure_feature_columns(self, df):
        """
        Ensure all columns in FEATURE_COLUMNS exist in the DataFrame.
        If a feature is missing, fill with zeros and log a warning.
        
        Args:
            df: DataFrame to validate
            
        Returns:
            DataFrame with all FEATURE_COLUMNS present
        """
        print("\n🔍 Validating FEATURE_COLUMNS...")
        
        missing_features = []
        for feature in FEATURE_COLUMNS:
            if feature not in df.columns:
                missing_features.append(feature)
                df[feature] = 0.0
                print(f"⚠️  Missing feature '{feature}' - filled with 0.0")
        
        if missing_features:
            print(f"⚠️  Warning: {len(missing_features)} features were missing and filled with zeros")
        else:
            print(f"✅ All {len(FEATURE_COLUMNS)} required features are present")
        
        # Ensure feature columns are in the correct order
        # Add any extra columns that exist but aren't in FEATURE_COLUMNS
        extra_cols = [col for col in df.columns if col not in FEATURE_COLUMNS and col not in ['final_ojt_grade', 'risk_level']]
        if extra_cols:
            print(f"📋 Found {len(extra_cols)} extra columns (will be excluded from features): {extra_cols[:5]}...")
        
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
        missing_target = df[target_column].isnull().sum() if target_column and target_column in df.columns else 0
        
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
        
        if target_column and target_column in df.columns and missing_target > 0:
            print(f"⚠️  Missing values in target '{target_column}': {missing_target}")
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
        
        # Only clamp true grading score columns to 0–100.
        # Hours / exposure features (e.g., competency hours, total_hours_completed)
        # are allowed to exceed 100 and should not be clipped.
        grade_columns = [
            "weekly_progress_grade",
            "narrative_report_grade",
            "coordinator_eval_grade",
            "supervisor_eval_grade",
        ]
        numeric_grade_cols = [c for c in grade_columns if c in df.columns]

        if numeric_grade_cols:
            negative_scores = (df[numeric_grade_cols] < 0).sum().sum()
            if negative_scores > 0:
                print(f"⚠️  Found {negative_scores} negative grade values. Clipping to 0...")
                for col in numeric_grade_cols:
                    df[col] = df[col].clip(lower=0)

            high_scores = (df[numeric_grade_cols] > 100).sum().sum()
            if high_scores > 0:
                print(f"⚠️  Found {high_scores} grade values > 100. Clipping to 100...")
                for col in numeric_grade_cols:
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
    
    def map_csv_to_features(self, df):
        """
        Map CSV columns to standard FEATURE_COLUMNS.
        Handles various column name formats from the CSV.
        
        Args:
            df: DataFrame with original CSV columns
            
        Returns:
            DataFrame with mapped feature columns
        """
        print("\n🔄 Mapping CSV columns to standard feature names...")
        
        # Map grading components
        grading_mapping = self.map_grading_components(df)
        
        # Create mapping dictionary: standard_name -> csv_column_name
        column_mapping = {}
        
        # Map grading components
        if grading_mapping.get('WPR'):
            column_mapping['weekly_progress_grade'] = grading_mapping['WPR']
            df['has_weekly_progress_grade'] = (df[grading_mapping['WPR']].notna() & (df[grading_mapping['WPR']] > 0)).astype(int)
        else:
            df['weekly_progress_grade'] = 0.0
            df['has_weekly_progress_grade'] = 0
        
        if grading_mapping.get('NR'):
            column_mapping['narrative_report_grade'] = grading_mapping['NR']
            df['has_narrative_report_grade'] = (df[grading_mapping['NR']].notna() & (df[grading_mapping['NR']] > 0)).astype(int)
        else:
            df['narrative_report_grade'] = 0.0
            df['has_narrative_report_grade'] = 0
        
        if grading_mapping.get('CE'):
            column_mapping['coordinator_eval_grade'] = grading_mapping['CE']
            df['has_coordinator_eval_grade'] = (df[grading_mapping['CE']].notna() & (df[grading_mapping['CE']] > 0)).astype(int)
        else:
            df['coordinator_eval_grade'] = 0.0
            df['has_coordinator_eval_grade'] = 0
        
        if grading_mapping.get('SE'):
            column_mapping['supervisor_eval_grade'] = grading_mapping['SE']
            df['has_supervisor_eval_grade'] = (df[grading_mapping['SE']].notna() & (df[grading_mapping['SE']] > 0)).astype(int)
        else:
            df['supervisor_eval_grade'] = 0.0
            df['has_supervisor_eval_grade'] = 0
        
        # Map attendance (try various column names)
        attendance_cols = [col for col in df.columns if 'attendance' in col.lower() and ('days' in col.lower() or 'present' in col.lower())]
        if attendance_cols:
            # Convert days present to attendance rate (assuming 25 days total, or calculate from data)
            days_present_col = attendance_cols[0]
            total_days = 25  # Default, can be adjusted
            df['attendance_rate'] = (df[days_present_col] / total_days * 100).fillna(0.0)
            # Estimate total hours (assuming 8 hours per day)
            df['total_hours_completed'] = (df[days_present_col] * 8).fillna(0.0)
        else:
            df['attendance_rate'] = 0.0
            df['total_hours_completed'] = 0.0
        
        # Set defaults for other features if not present
        if 'required_hours' not in df.columns:
            df['required_hours'] = 300.0
        
        if 'hours_completed_ratio' not in df.columns:
            df['hours_completed_ratio'] = df['total_hours_completed'] / df['required_hours'].replace(0, 300.0)
            df['hours_completed_ratio'] = df['hours_completed_ratio'].fillna(0.0)
        
        default_features = {
            'late_count': 0.0,
            'absent_count': 0.0,
            'total_tasks_logged': 0.0,
            'total_task_hours': 0.0,
            'number_of_distinct_competencies': 0.0,
            'hours_software_development': 0.0,
            'hours_machine_learning_engineering': 0.0,
            'hours_it_related_research': 0.0,
            'hours_ux_ui_design': 0.0,
            'hours_information_security_analysis': 0.0,
            'hours_networking': 0.0,
            'hours_technical_support': 0.0,
            'hours_data_analysis': 0.0,
            'hours_customer_service': 0.0,
            'hours_data_entry_management': 0.0,
            'hours_office_work': 0.0,
            'total_chatbot_queries': 0.0,
            'chatbot_queries_last_30_days': 0.0
        }
        
        for feature, default_value in default_features.items():
            if feature not in df.columns:
                df[feature] = default_value
        
        # Compute final grade and risk
        df = self.compute_final_grade_and_risk(df, grading_mapping)
        
        # Ensure all FEATURE_COLUMNS exist
        df = self.ensure_feature_columns(df)
        
        print("✅ CSV column mapping completed!")
        
        return df
    
    def fit(self, df, feature_columns=None, target_column=None):
        """
        Fit the preprocessor on training data
        """
        print("🚀 FITTING DATA PREPROCESSOR")
        print("="*50)
        
        # Map CSV columns to standard features
        df = self.map_csv_to_features(df)
        
        # Use FEATURE_COLUMNS as the feature set
        feature_columns = FEATURE_COLUMNS.copy()
        target_column = 'risk_level'
        
        self.feature_names = feature_columns
        self.target_column = target_column
        
        print(f"🎯 Target column: {target_column}")
        print(f"🔧 Feature columns: {len(feature_columns)} features")
        
        # Handle missing values
        df_clean = self.handle_missing_values(df, feature_columns, target_column)
        
        # Convert categorical features to numerical (if any remain)
        df_numeric, categorical_mapping = self.convert_categorical_features(df_clean, feature_columns)
        
        # Validate data (ensure all features are numeric and in valid ranges)
        df_final = self.validate_data(df_numeric, feature_columns, target_column)
        
        # Fit scaler on features only
        X = df_final[feature_columns].values
        self.scaler.fit(X)
        
        # Fit label encoder on target
        y = df_final[target_column].values
        self.label_encoder.fit(y)
        
        self.is_fitted = True
        
        print("✅ Preprocessor fitting completed!")
        
        return df_final, feature_columns, target_column, categorical_mapping
    
    def transform(self, df, feature_columns=None):
        """
        Transform new data using fitted preprocessor
        """
        if not self.is_fitted:
            raise ValueError("❌ Preprocessor must be fitted before transformation")
        
        if feature_columns is None:
            feature_columns = self.feature_names
        
        print("🔄 Transforming data...")
        
        # Map CSV columns if needed (for new data)
        if 'risk_level' not in df.columns or 'final_ojt_grade' not in df.columns:
            df = self.map_csv_to_features(df)
        
        # Ensure all feature columns exist
        df = self.ensure_feature_columns(df)
        
        # Handle missing values
        df_clean = self.handle_missing_values(df, feature_columns, self.target_column if self.target_column in df.columns else None)
        
        # Convert categorical features (using same mapping as fit)
        df_numeric, _ = self.convert_categorical_features(df_clean, feature_columns)
        
        # Apply scaling
        X = df_numeric[feature_columns].values
        X_scaled = self.scaler.transform(X)
        
        # Prepare target
        if self.target_column in df_numeric.columns:
            y = df_numeric[self.target_column].values
            try:
                y_encoded = self.label_encoder.transform(y)
            except ValueError:
                # Handle unseen labels in target
                print("⚠️  Unknown labels in target, using original values")
                y_encoded = y
        else:
            y_encoded = None
        
        print(f"✅ Data transformation completed: {X_scaled.shape}")
        
        return X_scaled, y_encoded if y_encoded is not None else None, feature_columns
    
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