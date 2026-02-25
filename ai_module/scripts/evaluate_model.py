# scripts/evaluate_model.py

import pandas as pd
import numpy as np
import pickle
import os
import sys
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.metrics import (
    accuracy_score, classification_report, confusion_matrix,
    precision_score, recall_score, f1_score, roc_auc_score, roc_curve,
    precision_recall_curve, average_precision_score
)
from sklearn.preprocessing import label_binarize
import warnings
warnings.filterwarnings('ignore')

# Add parent directory to path to import modules
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

class ModelEvaluator:
    """
    Comprehensive model evaluation for the ensemble and individual models
    """
    
    def __init__(self, models_dir="models"):
        self.models_dir = models_dir
        self.ensemble = None
        self.lr_model = None
        self.rf_model = None
        self.nb_model = None
        self.scaler = None
        self.feature_names = None
        self.label_encoder = None
        
    def load_models(self):
        """Load all trained models and artifacts"""
        try:
            print("📁 Loading trained models...")
            
            self.ensemble = pickle.load(open(os.path.join(self.models_dir, "ensemble_model.pkl"), 'rb'))
            self.lr_model = pickle.load(open(os.path.join(self.models_dir, "logistic_regression.pkl"), 'rb'))
            self.rf_model = pickle.load(open(os.path.join(self.models_dir, "random_forest.pkl"), 'rb'))
            self.nb_model = pickle.load(open(os.path.join(self.models_dir, "naive_bayes.pkl"), 'rb'))
            self.scaler = pickle.load(open(os.path.join(self.models_dir, "scaler.pkl"), 'rb'))
            self.feature_names = pickle.load(open(os.path.join(self.models_dir, "feature_names.pkl"), 'rb'))
            self.label_encoder = pickle.load(open(os.path.join(self.models_dir, "label_encoder.pkl"), 'rb'))
            
            print("✅ All models loaded successfully!")
            return True
            
        except Exception as e:
            print(f"❌ Error loading models: {e}")
            return False
    
    def load_test_data(self):
        """Load or create test data for evaluation"""
        data_path = "data/datasets/ojt_grading_data.csv"
        
        if not os.path.exists(data_path):
            print("❌ No test data found. Please run training first or provide test data.")
            return None, None, None
        
        print("📊 Loading test data...")
        df = pd.read_csv(data_path)
        
        # Use the same feature detection as training
        from scripts.train_model import detect_feature_columns, detect_target_column
        
        feature_columns = detect_feature_columns(df)
        target_column = detect_target_column(df)
        
        X = df[feature_columns].values
        y = df[target_column].values
        
        print(f"🔍 Features: {feature_columns}")
        print(f"🎯 Target: {target_column}")
        print(f"📈 Test data shape: {X.shape}")
        
        return X, y, feature_columns
    
    def evaluate_individual_models(self, X_test, y_test):
        """Evaluate each individual model"""
        print("\n" + "="*60)
        print("📊 INDIVIDUAL MODEL EVALUATION")
        print("="*60)
        
        X_test_scaled = self.scaler.transform(X_test)
        y_test_encoded = self.label_encoder.transform(y_test)
        
        models = {
            "Logistic Regression": self.lr_model,
            "Random Forest": self.rf_model,
            "Naive Bayes": self.nb_model
        }
        
        results = {}
        
        for name, model in models.items():
            print(f"\n🔍 Evaluating {name}...")
            
            if name == "Logistic Regression" or name == "Naive Bayes":
                predictions = model.predict(X_test_scaled)
                probabilities = model.predict_proba(X_test_scaled)
            else:
                predictions = model.predict(X_test)
                probabilities = model.predict_proba(X_test)
            
            # Convert predictions back to original labels
            predictions_decoded = self.label_encoder.inverse_transform(predictions)
            
            # Calculate metrics
            accuracy = accuracy_score(y_test, predictions_decoded)
            precision = precision_score(y_test, predictions_decoded, average='weighted', zero_division=0)
            recall = recall_score(y_test, predictions_decoded, average='weighted', zero_division=0)
            f1 = f1_score(y_test, predictions_decoded, average='weighted', zero_division=0)
            
            results[name] = {
                'accuracy': accuracy,
                'precision': precision,
                'recall': recall,
                'f1_score': f1,
                'predictions': predictions_decoded,
                'probabilities': probabilities
            }
            
            print(f"   ✅ Accuracy: {accuracy:.4f}")
            print(f"   ✅ Precision: {precision:.4f}")
            print(f"   ✅ Recall: {recall:.4f}")
            print(f"   ✅ F1-Score: {f1:.4f}")
            
            # Detailed classification report
            print(f"\n   📋 Classification Report:")
            report = classification_report(y_test, predictions_decoded, output_dict=True)
            for class_name in self.label_encoder.classes_:
                if class_name in report:
                    class_report = report[class_name]
                    print(f"      {class_name}: "
                          f"Precision={class_report['precision']:.3f}, "
                          f"Recall={class_report['recall']:.3f}, "
                          f"F1={class_report['f1-score']:.3f}")
        
        return results
    
    def evaluate_ensemble(self, X_test, y_test):
        """Evaluate the ensemble model"""
        print("\n" + "="*60)
        print("🔥 ENSEMBLE MODEL EVALUATION")
        print("="*60)
        
        ensemble_predictions = self.ensemble.predict(X_test)
        ensemble_probabilities = self.ensemble.predict_proba(X_test)
        
        # Calculate metrics
        accuracy = accuracy_score(y_test, ensemble_predictions)
        precision = precision_score(y_test, ensemble_predictions, average='weighted', zero_division=0)
        recall = recall_score(y_test, ensemble_predictions, average='weighted', zero_division=0)
        f1 = f1_score(y_test, ensemble_predictions, average='weighted', zero_division=0)
        
        print(f"✅ Ensemble Accuracy: {accuracy:.4f}")
        print(f"✅ Ensemble Precision: {precision:.4f}")
        print(f"✅ Ensemble Recall: {recall:.4f}")
        print(f"✅ Ensemble F1-Score: {f1:.4f}")
        
        # Detailed classification report
        print(f"\n📋 Detailed Classification Report:")
        print(classification_report(y_test, ensemble_predictions, target_names=self.label_encoder.classes_))
        
        results = {
            'accuracy': accuracy,
            'precision': precision,
            'recall': recall,
            'f1_score': f1,
            'predictions': ensemble_predictions,
            'probabilities': ensemble_probabilities
        }
        
        return results
    
    def plot_confusion_matrix(self, y_true, y_pred, model_name="Model"):
        """Plot confusion matrix"""
        plt.figure(figsize=(8, 6))
        cm = confusion_matrix(y_true, y_pred, labels=self.label_encoder.classes_)
        
        sns.heatmap(cm, annot=True, fmt='d', cmap='Blues',
                   xticklabels=self.label_encoder.classes_,
                   yticklabels=self.label_encoder.classes_)
        
        plt.title(f'Confusion Matrix - {model_name}')
        plt.xlabel('Predicted')
        plt.ylabel('Actual')
        plt.tight_layout()
        
        # Save the plot
        os.makedirs('evaluation_plots', exist_ok=True)
        plt.savefig(f'evaluation_plots/confusion_matrix_{model_name.lower().replace(" ", "_")}.png', dpi=300, bbox_inches='tight')
        plt.show()
    
    def plot_feature_importance(self):
        """Plot feature importance from Random Forest"""
        if hasattr(self.rf_model, 'feature_importances_'):
            plt.figure(figsize=(10, 6))
            
            importance_df = pd.DataFrame({
                'feature': self.feature_names,
                'importance': self.rf_model.feature_importances_
            }).sort_values('importance', ascending=True)
            
            plt.barh(importance_df['feature'], importance_df['importance'])
            plt.title('Random Forest Feature Importance')
            plt.xlabel('Importance Score')
            plt.tight_layout()
            
            # Save the plot
            os.makedirs('evaluation_plots', exist_ok=True)
            plt.savefig('evaluation_plots/feature_importance.png', dpi=300, bbox_inches='tight')
            plt.show()
            
            return importance_df
        return None
    
    def plot_model_comparison(self, individual_results, ensemble_results):
        """Plot comparison of all models"""
        models = list(individual_results.keys()) + ['Ensemble']
        accuracies = [individual_results[model]['accuracy'] for model in individual_results.keys()] + [ensemble_results['accuracy']]
        f1_scores = [individual_results[model]['f1_score'] for model in individual_results.keys()] + [ensemble_results['f1_score']]
        
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(15, 6))
        
        # Accuracy comparison
        bars1 = ax1.bar(models, accuracies, color=['skyblue', 'lightgreen', 'lightcoral', 'gold'])
        ax1.set_title('Model Accuracy Comparison')
        ax1.set_ylabel('Accuracy')
        ax1.set_ylim(0, 1)
        for bar, accuracy in zip(bars1, accuracies):
            ax1.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.01,
                    f'{accuracy:.3f}', ha='center', va='bottom')
        
        # F1-Score comparison
        bars2 = ax2.bar(models, f1_scores, color=['skyblue', 'lightgreen', 'lightcoral', 'gold'])
        ax2.set_title('Model F1-Score Comparison')
        ax2.set_ylabel('F1-Score')
        ax2.set_ylim(0, 1)
        for bar, f1 in zip(bars2, f1_scores):
            ax2.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.01,
                    f'{f1:.3f}', ha='center', va='bottom')
        
        plt.tight_layout()
        
        # Save the plot
        os.makedirs('evaluation_plots', exist_ok=True)
        plt.savefig('evaluation_plots/model_comparison.png', dpi=300, bbox_inches='tight')
        plt.show()
    
    def generate_performance_report(self, individual_results, ensemble_results):
        """Generate a comprehensive performance report"""
        print("\n" + "="*60)
        print("📈 COMPREHENSIVE PERFORMANCE REPORT")
        print("="*60)
        
        # Create comparison table
        comparison_data = []
        for model_name, results in individual_results.items():
            comparison_data.append({
                'Model': model_name,
                'Accuracy': f"{results['accuracy']:.4f}",
                'Precision': f"{results['precision']:.4f}",
                'Recall': f"{results['recall']:.4f}",
                'F1-Score': f"{results['f1_score']:.4f}"
            })
        
        comparison_data.append({
            'Model': 'ENSEMBLE',
            'Accuracy': f"{ensemble_results['accuracy']:.4f}",
            'Precision': f"{ensemble_results['precision']:.4f}",
            'Recall': f"{ensemble_results['recall']:.4f}",
            'F1-Score': f"{ensemble_results['f1_score']:.4f}"
        })
        
        comparison_df = pd.DataFrame(comparison_data)
        print("\n📊 Model Performance Comparison:")
        print(comparison_df.to_string(index=False))
        
        # Calculate improvement over best individual model
        best_individual_accuracy = max([results['accuracy'] for results in individual_results.values()])
        improvement = ensemble_results['accuracy'] - best_individual_accuracy
        
        print(f"\n🚀 Ensemble Improvement over Best Individual Model: {improvement:.4f} "
              f"({improvement/best_individual_accuracy*100:.2f}%)")
        
        # Save report to file
        report_content = f"""
OJT PREDICTION MODEL EVALUATION REPORT
======================================

ENSEMBLE MODEL PERFORMANCE:
- Accuracy: {ensemble_results['accuracy']:.4f}
- Precision: {ensemble_results['precision']:.4f}
- Recall: {ensemble_results['recall']:.4f}
- F1-Score: {ensemble_results['f1_score']:.4f}

INDIVIDUAL MODEL PERFORMANCE:
"""
        for model_name, results in individual_results.items():
            report_content += f"""
{model_name}:
- Accuracy: {results['accuracy']:.4f}
- Precision: {results['precision']:.4f}
- Recall: {results['recall']:.4f}
- F1-Score: {results['f1_score']:.4f}
"""
        
        report_content += f"""
IMPROVEMENT:
- Ensemble vs Best Individual: {improvement:.4f} ({improvement/best_individual_accuracy*100:.2f}%)

FEATURES USED: {', '.join(self.feature_names)}
TARGET CLASSES: {', '.join(self.label_encoder.classes_)}
"""
        
        os.makedirs('evaluation_reports', exist_ok=True)
        with open('evaluation_reports/performance_report.txt', 'w') as f:
            f.write(report_content)
        
        print(f"\n💾 Performance report saved to: evaluation_reports/performance_report.txt")
        
        return comparison_df
    
    def run_complete_evaluation(self, test_size=0.3):
        """Run complete evaluation pipeline"""
        print("🚀 STARTING COMPREHENSIVE MODEL EVALUATION")
        print("="*60)
        
        # Load models
        if not self.load_models():
            return
        
        # Load test data
        X, y, feature_columns = self.load_test_data()
        if X is None:
            return
        
        # Split data for evaluation (using different split than training)
        from sklearn.model_selection import train_test_split
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=test_size, random_state=42, stratify=y
        )
        
        print(f"\n📊 Evaluation Data Split:")
        print(f"   Training samples: {X_train.shape[0]}")
        print(f"   Testing samples: {X_test.shape[0]}")
        
        # Evaluate individual models
        individual_results = self.evaluate_individual_models(X_test, y_test)
        
        # Evaluate ensemble model
        ensemble_results = self.evaluate_ensemble(X_test, y_test)
        
        # Generate plots
        print("\n📊 Generating evaluation plots...")
        
        # Confusion matrices
        for model_name, results in individual_results.items():
            self.plot_confusion_matrix(y_test, results['predictions'], model_name)
        
        self.plot_confusion_matrix(y_test, ensemble_results['predictions'], "Ensemble")
        
        # Feature importance
        importance_df = self.plot_feature_importance()
        if importance_df is not None:
            print("\n🔍 Feature Importance Ranking:")
            for _, row in importance_df.sort_values('importance', ascending=False).iterrows():
                print(f"   {row['feature']}: {row['importance']:.4f}")
        
        # Model comparison
        self.plot_model_comparison(individual_results, ensemble_results)
        
        # Generate comprehensive report
        comparison_df = self.generate_performance_report(individual_results, ensemble_results)
        
        print("\n✅ EVALUATION COMPLETED SUCCESSFULLY!")
        print("📁 Evaluation results saved in:")
        print("   - evaluation_plots/ (visualizations)")
        print("   - evaluation_reports/ (performance reports)")
        
        return {
            'individual_results': individual_results,
            'ensemble_results': ensemble_results,
            'comparison_df': comparison_df,
            'feature_importance': importance_df
        }

def quick_evaluation():
    """Quick evaluation without plots for fast checking"""
    evaluator = ModelEvaluator()
    
    if not evaluator.load_models():
        return
    
    X, y, _ = evaluator.load_test_data()
    if X is None:
        return
    
    # Use a small test split for quick evaluation
    from sklearn.model_selection import train_test_split
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    print("🚀 QUICK EVALUATION")
    print("="*50)
    
    # Individual models
    individual_results = evaluator.evaluate_individual_models(X_test, y_test)
    
    # Ensemble
    ensemble_results = evaluator.evaluate_ensemble(X_test, y_test)
    
    # Quick comparison
    print("\n📈 QUICK COMPARISON:")
    for model_name, results in individual_results.items():
        print(f"   {model_name}: {results['accuracy']:.4f}")
    print(f"   ENSEMBLE: {ensemble_results['accuracy']:.4f}")

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Evaluate OJT Prediction Models')
    parser.add_argument('--quick', action='store_true', help='Run quick evaluation without plots')
    parser.add_argument('--test-size', type=float, default=0.3, help='Test set size ratio (default: 0.3)')
    
    args = parser.parse_args()
    
    if args.quick:
        quick_evaluation()
    else:
        evaluator = ModelEvaluator()
        results = evaluator.run_complete_evaluation(test_size=args.test_size)