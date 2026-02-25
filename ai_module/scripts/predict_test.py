"""Test script for OJT AI Prediction System"""
import pandas as pd
import numpy as np
import os
import sys

# Add parent directory to path to import modules
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Import insight engine
from ollama_integration import insight_engine


def check_system_ready():
    """Check if the system is ready for predictions"""
    print("🔍 Checking system status...")
    
    required_files = [
        "models/ensemble_model.pkl",
        "models/scaler.pkl", 
        "models/feature_names.pkl",
        "models/label_encoder.pkl"
    ]
    
    status = {}
    for file in required_files:
        exists = os.path.exists(file)
        status[file] = exists
        icon = "✅" if exists else "❌"
        print(f"   {icon} {file}")
    
    all_ready = all(status.values())
    
    if not all_ready:
        print("\n❌ System not ready for predictions.")
        print("💡 Please run training first: python scripts/train_model.py")
        return False
    
    print("✅ System is ready for predictions!")
    return True

def create_sample_snapshot(wpr, nr, ce, se, attendance_rate=80.0, total_hours=150.0, required_hours=300.0):
    """
    Create a sample feature snapshot matching FEATURE_COLUMNS structure
    """
    return {
        "total_hours_completed": total_hours,
        "required_hours": required_hours,
        "attendance_rate": attendance_rate,
        "late_count": 2.0,
        "absent_count": 5.0,
        "hours_completed_ratio": total_hours / required_hours,
        "total_tasks_logged": 20.0,
        "total_task_hours": 80.0,
        "number_of_distinct_competencies": 5.0,
        "hours_software_development": 40.0,
        "hours_machine_learning_engineering": 0.0,
        "hours_it_related_research": 0.0,
        "hours_ux_ui_design": 0.0,
        "hours_information_security_analysis": 0.0,
        "hours_networking": 0.0,
        "hours_technical_support": 10.0,
        "hours_data_analysis": 0.0,
        "hours_customer_service": 0.0,
        "hours_data_entry_management": 0.0,
        "hours_office_work": 30.0,
        "weekly_progress_grade": wpr,
        "narrative_report_grade": nr,
        "coordinator_eval_grade": ce,
        "supervisor_eval_grade": se,
        "has_weekly_progress_grade": 1 if wpr > 0 else 0,
        "has_narrative_report_grade": 1 if nr > 0 else 0,
        "has_coordinator_eval_grade": 1 if ce > 0 else 0,
        "has_supervisor_eval_grade": 1 if se > 0 else 0,
        "total_chatbot_queries": 15.0,
        "chatbot_queries_last_30_days": 8.0
    }

def test_sample_predictions():
    """Test predictions with sample student data"""
    print("\n🧪 TESTING SAMPLE PREDICTIONS")
    print("=" * 50)
    
    # Sample students covering different performance scenarios
    test_students = [
        {
            'name': '🚨 High Risk Student',
            'snapshot': create_sample_snapshot(45, 50, 55, 48, attendance_rate=60.0, total_hours=100.0),
            'description': 'Low scores across all metrics, poor attendance'
        },
        {
            'name': '📊 Medium Risk Student',
            'snapshot': create_sample_snapshot(68, 72, 65, 70, attendance_rate=75.0, total_hours=200.0),
            'description': 'Mixed performance near thresholds'
        },
        {
            'name': '✅ Low Risk Student',
            'snapshot': create_sample_snapshot(75, 78, 82, 80, attendance_rate=85.0, total_hours=250.0),
            'description': 'Meets expectations consistently'
        },
        {
            'name': '🌟 Excellent Student', 
            'snapshot': create_sample_snapshot(92, 88, 95, 94, attendance_rate=95.0, total_hours=280.0),
            'description': 'Outstanding performance'
        }
    ]
    
    results = []
    
    for student in test_students:
        print(f"\n🎓 {student['name']}")
        print(f"   📝 {student['description']}")
        
        try:
            # Make prediction using predict_with_explanation
            result = insight_engine.predict_with_explanation(student['snapshot'])
            
            if result.get('success', False):
                ml_pred = result.get('ml_prediction', {})
                risk_level = ml_pred.get('risk_level', 'UNKNOWN')
                confidence = ml_pred.get('probability', 0.0)
                reasons = ml_pred.get('top_reasons', [])
                recommendation = ml_pred.get('recommendation', '')
                
                # Store results for summary
                results.append({
                    'name': student['name'],
                    'risk_level': risk_level,
                    'confidence': confidence,
                    'snapshot': student['snapshot']
                })
                
                # Display results
                print(f"   🎯 Risk Level: {risk_level}")
                print(f"   📈 Confidence: {confidence:.1%}")
                
                # Show key reasons
                if reasons:
                    print(f"   💡 Key Reasons:")
                    for reason in reasons[:3]:  # Show first 3 reasons
                        print(f"      • {reason}")
                
                # Show recommendation
                if recommendation:
                    print(f"   🚀 Recommendation: {recommendation[:100]}...")
                
            else:
                error_msg = result.get('message', 'Unknown error')
                print(f"   ❌ Prediction failed: {error_msg}")
                
        except Exception as e:
            print(f"   ❌ Error: {e}")
            import traceback
            traceback.print_exc()
    
    return results

def print_prediction_summary(results):
    """Print a summary of all predictions"""
    print("\n" + "=" * 60)
    print("📊 PREDICTION SUMMARY")
    print("=" * 60)
    
    if not results:
        print("❌ No successful predictions to summarize")
        return
    
    # Count predictions by category
    prediction_counts = {}
    confidence_scores = []
    
    for result in results:
        category = result['risk_level']
        prediction_counts[category] = prediction_counts.get(category, 0) + 1
        confidence_scores.append(result['confidence'])
    
    print("\n📈 Distribution:")
    for category, count in prediction_counts.items():
        percentage = (count / len(results)) * 100
        print(f"   {category}: {count} student(s) ({percentage:.0f}%)")
    
    print(f"\n🎯 Average Confidence: {np.mean(confidence_scores):.1%}")
    print(f"📊 Confidence Range: {min(confidence_scores):.1%} - {max(confidence_scores):.1%}")
    
    # Show most confident prediction
    most_confident = max(results, key=lambda x: x['confidence'])
    least_confident = min(results, key=lambda x: x['confidence'])
    
    print(f"\n🔍 Most Confident: {most_confident['name']}")
    print(f"   Risk Level: {most_confident['risk_level']} ({most_confident['confidence']:.1%})")
    
    print(f"🔍 Least Confident: {least_confident['name']}")
    print(f"   Risk Level: {least_confident['risk_level']} ({least_confident['confidence']:.1%})")


def run_comprehensive_test():
    """Run all test functions"""
    print("🎓 OJT PREDICTION SYSTEM TEST")
    print("=" * 60)
    
    # Check if system is ready
    if not check_system_ready():
        return
    
    try:
        # Test sample predictions
        results = test_sample_predictions()
        
        # Print summary
        print_prediction_summary(results)
        
        print("\n🎉 ALL TESTS COMPLETED SUCCESSFULLY!")
        print("\n💡 Next steps:")
        print("   • Use the insight engine in your application")
        print("   • Integrate with your frontend or chatbot")
        print("   • Run 'python scripts/train_model.py' to retrain models if needed")
        
    except Exception as e:
        print(f"❌ Test failed: {e}")
        import traceback
        traceback.print_exc()

def quick_test():
    """Run a quick test without interactive input"""
    print("⚡ QUICK PREDICTION TEST")
    print("=" * 40)
    
    if not check_system_ready():
        return
    
    # Test just one sample
    sample_snapshot = create_sample_snapshot(85, 78, 92, 88)
    
    print(f"\n🔮 Testing prediction for sample student...")
    result = insight_engine.predict_with_explanation(sample_snapshot)
    
    if result.get('success', False):
        ml_pred = result.get('ml_prediction', {})
        risk_level = ml_pred.get('risk_level', 'UNKNOWN')
        confidence = ml_pred.get('probability', 0.0)
        print(f"✅ Risk Level: {risk_level}")
        print(f"✅ Confidence: {confidence:.1%}")
        print(f"✅ System is working correctly!")
    else:
        error_msg = result.get('message', 'Unknown error')
        print(f"❌ Test failed: {error_msg}")

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Test OJT Prediction System')
    parser.add_argument('--quick', action='store_true', help='Run quick test only')
    
    args = parser.parse_args()
    
    if args.quick:
        quick_test()
    else:
        run_comprehensive_test()