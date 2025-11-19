"""Test script for OJT AI Prediction System"""
import pandas as pd
import numpy as np
import os
import sys


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
        print("💡 Please run training first: python main.py")
        return False
    
    print("✅ System is ready for predictions!")
    return True

def test_sample_predictions():
    """Test predictions with sample student data"""
    print("\n🧪 TESTING SAMPLE PREDICTIONS")
    print("=" * 50)
    
    # Sample students covering different performance scenarios
    test_students = [
        {
            'name': '🚨 At-Risk Student',
            'data': {
                'weekly_progress': 45,
                'narrative_report': 50, 
                'coordinator_evaluation': 55,
                'partner_evaluation': 48
            },
            'description': 'Low scores across all metrics'
        },
        {
            'name': '📊 Borderline Student',
            'data': {
                'weekly_progress': 68,
                'narrative_report': 72,
                'coordinator_evaluation': 65, 
                'partner_evaluation': 70
            },
            'description': 'Mixed performance near thresholds'
        },
        {
            'name': '✅ Satisfactory Student',
            'data': {
                'weekly_progress': 75,
                'narrative_report': 78,
                'coordinator_evaluation': 82, 
                'partner_evaluation': 80
            },
            'description': 'Meets expectations consistently'
        },
        {
            'name': '🌟 Excellent Student', 
            'data': {
                'weekly_progress': 92,
                'narrative_report': 88,
                'coordinator_evaluation': 95,
                'partner_evaluation': 94
            },
            'description': 'Outstanding performance'
        },
        {
            'name': '⚡ Inconsistent Student',
            'data': {
                'weekly_progress': 85,
                'narrative_report': 60,  # Weak narrative
                'coordinator_evaluation': 90,
                'partner_evaluation': 88
            },
            'description': 'Strong in some areas, weak in others'
        }
    ]
    
    results = []
    
    for student in test_students:
        print(f"\n🎓 {student['name']}")
        print(f"   📝 {student['description']}")
        print(f"   📊 Data: {student['data']}")
        
        try:
            # Make prediction
            result = insight_engine.predict_student_performance(student['data'])
            
            if result['status'] == 'success':
                # Store results for summary
                results.append({
                    'name': student['name'],
                    'prediction': result['prediction'],
                    'confidence': result['confidence'],
                    'data': student['data']
                })
                
                # Display results
                print(f"   🎯 Prediction: {result['prediction']}")
                print(f"   📈 Confidence: {result['confidence']:.1%}")
                
                # Show key insights
                print(f"   💡 Key Insights:")
                for insight in result['insights'][:3]:  # Show first 3 insights
                    print(f"      • {insight}")
                
                # Show top recommendation
                if result['recommendations']:
                    print(f"   🚀 Recommendation: {result['recommendations'][0]}")
                
            else:
                print(f"   ❌ Prediction failed: {result.get('error', 'Unknown error')}")
                
        except Exception as e:
            print(f"   ❌ Error: {e}")
    
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
        category = result['prediction']
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
    print(f"   Prediction: {most_confident['prediction']} ({most_confident['confidence']:.1%})")
    
    print(f"🔍 Least Confident: {least_confident['name']}")
    print(f"   Prediction: {least_confident['prediction']} ({least_confident['confidence']:.1%})")

def interactive_prediction():
    """Allow user to input custom student data"""
    print("\n🎯 INTERACTIVE PREDICTION")
    print("=" * 40)
    print("Enter student scores (0-100 scale):")
    
    try:
        weekly_progress = float(input("📈 Weekly Progress: "))
        narrative_report = float(input("📝 Narrative Report: "))
        coordinator_evaluation = float(input("👨‍🏫 Coordinator Evaluation: "))
        partner_evaluation = float(input("🤝 Partner Evaluation: "))
        
        student_data = {
            'weekly_progress': weekly_progress,
            'narrative_report': narrative_report,
            'coordinator_evaluation': coordinator_evaluation,
            'partner_evaluation': partner_evaluation
        }
        
        # Validate inputs
        for key, value in student_data.items():
            if value < 0 or value > 100:
                print(f"❌ {key} must be between 0 and 100")
                return
        
        print(f"\n🔮 Predicting for student with scores:")
        print(f"   Weekly Progress: {weekly_progress}%")
        print(f"   Narrative Report: {narrative_report}%")
        print(f"   Coordinator Evaluation: {coordinator_evaluation}%")
        print(f"   Partner Evaluation: {partner_evaluation}%")
        
        # Make prediction
        result = insight_engine.predict_student_performance(student_data)
        
        if result['status'] == 'success':
            display_detailed_results(result)
        else:
            print(f"❌ Prediction failed: {result.get('error', 'Unknown error')}")
            
    except ValueError:
        print("❌ Please enter valid numbers!")
    except KeyboardInterrupt:
        print("\n👋 Prediction cancelled by user")
    except Exception as e:
        print(f"❌ Error: {e}")

def display_detailed_results(result):
    """Display detailed prediction results"""
    print("\n" + "🎓" * 20)
    print("🎯 PREDICTION RESULTS")
    print("🎓" * 20)
    
    print(f"\n📊 PERFORMANCE CATEGORY: {result['prediction']}")
    print(f"🎯 CONFIDENCE LEVEL: {result['confidence']:.1%}")
    
    # Probability breakdown
    print(f"\n📈 PROBABILITY BREAKDOWN:")
    for category, prob in result['probabilities'].items():
        bar = "█" * int(prob * 20)
        print(f"   {category:<12} {prob:>6.1%} {bar}")
    
    # Insights
    print(f"\n💡 KEY INSIGHTS:")
    for insight in result['insights']:
        print(f"   • {insight}")
    
    # Recommendations
    print(f"\n🚀 RECOMMENDATIONS:")
    for i, recommendation in enumerate(result['recommendations'], 1):
        print(f"   {i}. {recommendation}")
    
    # Risk Analysis
    risk_analysis = result['risk_analysis']
    print(f"\n⚠️  RISK ANALYSIS:")
    print(f"   Risk Level: {risk_analysis['risk_level'].upper()}")
    if risk_analysis['factors']:
        print(f"   Key Factors:")
        for factor in risk_analysis['factors']:
            print(f"     - {factor}")
    if risk_analysis['mitigation_strategies']:
        print(f"   Mitigation Strategies:")
        for strategy in risk_analysis['mitigation_strategies']:
            print(f"     - {strategy}")

def batch_prediction_demo():
    """Demonstrate batch predictions"""
    print("\n👥 BATCH PREDICTION DEMO")
    print("=" * 40)
    
    # Simulate a batch of students
    batch_students = [
        {'weekly_progress': 85, 'narrative_report': 78, 'coordinator_evaluation': 92, 'partner_evaluation': 88},
        {'weekly_progress': 65, 'narrative_report': 72, 'coordinator_evaluation': 68, 'partner_evaluation': 70},
        {'weekly_progress': 95, 'narrative_report': 88, 'coordinator_evaluation': 92, 'partner_evaluation': 94},
        {'weekly_progress': 55, 'narrative_report': 60, 'coordinator_evaluation': 58, 'partner_evaluation': 62},
        {'weekly_progress': 75, 'narrative_report': 82, 'coordinator_evaluation': 78, 'partner_evaluation': 80}
    ]
    
    print(f"📦 Processing {len(batch_students)} students...")
    
    results = insight_engine.batch_predict(batch_students)
    
    print(f"\n📊 BATCH RESULTS SUMMARY:")
    print("-" * 30)
    
    predictions_summary = {}
    for i, result in enumerate(results, 1):
        if result['status'] == 'success':
            pred = result['prediction']
            predictions_summary[pred] = predictions_summary.get(pred, 0) + 1
            
            status_icon = "✅" if pred != "At Risk" else "⚠️"
            print(f"   Student {i}: {status_icon} {pred} ({result['confidence']:.1%})")
        else:
            print(f"   Student {i}: ❌ Failed")
    
    print(f"\n📈 BATCH STATISTICS:")
    for pred, count in predictions_summary.items():
        percentage = (count / len(batch_students)) * 100
        print(f"   {pred}: {count} students ({percentage:.0f}%)")

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
        
        # Interactive prediction
        interactive_prediction()
        
        # Batch prediction demo
        batch_prediction_demo()
        
        print("\n🎉 ALL TESTS COMPLETED SUCCESSFULLY!")
        print("\n💡 Next steps:")
        print("   • Use the insight engine in your application")
        print("   • Integrate with your frontend or chatbot")
        print("   • Run 'python main.py' to retrain models if needed")
        
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
    sample_student = {
        'weekly_progress': 85,
        'narrative_report': 78,
        'coordinator_evaluation': 92,
        'partner_evaluation': 88
    }
    
    print(f"\n🔮 Testing prediction for sample student...")
    result = insight_engine.predict_student_performance(sample_student)
    
    if result['status'] == 'success':
        print(f"✅ Prediction: {result['prediction']}")
        print(f"✅ Confidence: {result['confidence']:.1%}")
        print(f"✅ System is working correctly!")
    else:
        print(f"❌ Test failed: {result.get('error', 'Unknown error')}")

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description='Test OJT Prediction System')
    parser.add_argument('--quick', action='store_true', help='Run quick test only')
    parser.add_argument('--interactive', action='store_true', help='Run only interactive prediction')
    parser.add_argument('--batch', action='store_true', help='Run only batch prediction demo')
    
    args = parser.parse_args()
    
    if args.quick:
        quick_test()
    elif args.interactive:
        if check_system_ready():
            interactive_prediction()
    elif args.batch:
        if check_system_ready():
            batch_prediction_demo()
    else:
        run_comprehensive_test()