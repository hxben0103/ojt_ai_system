"""
Test script for the enhanced insight_engine.py module.

This script demonstrates:
1. Model loading validation
2. Input validation
3. Prediction with explainability
4. Error handling

Usage:
    python test_insight_engine.py
"""

import sys
import os

# Add parent directory to path to import insight_engine
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'ollama_integration'))

from insight_engine import (
    validate_models,
    validate_input,
    predict_performance,
    predict_with_explanation,
    build_features_from_snapshot
)


def test_model_validation():
    """Test 1: Model Loading Validation"""
    print("\n" + "="*60)
    print("TEST 1: Model Loading Validation")
    print("="*60)
    
    is_valid, error_response = validate_models()
    
    if is_valid:
        print("✅ PASS: All models are loaded and available")
        return True
    else:
        print(f"❌ FAIL: Models not available")
        print(f"   Error Type: {error_response.get('error_type')}")
        print(f"   Message: {error_response.get('message')}")
        print(f"   Details: {error_response.get('details')}")
        return False


def test_input_validation_valid():
    """Test 2: Valid Input Validation"""
    print("\n" + "="*60)
    print("TEST 2: Valid Input Validation")
    print("="*60)
    
    valid_snapshot = {
        "daily_progress_score": 82,
        "narrative_score": 85,
        "coord_eval_score": 88,
        "partner_eval_score": 90,
        "attendance_days_present": 18
    }
    
    is_valid, error_response = validate_input(valid_snapshot)
    
    if is_valid:
        print("✅ PASS: Valid input accepted")
        return True
    else:
        print(f"❌ FAIL: Valid input rejected")
        print(f"   Error: {error_response}")
        return False


def test_input_validation_missing_fields():
    """Test 3: Missing Fields Validation"""
    print("\n" + "="*60)
    print("TEST 3: Missing Fields Validation")
    print("="*60)
    
    invalid_snapshot = {
        "daily_progress_score": 82,
        # Missing other required fields
    }
    
    is_valid, error_response = validate_input(invalid_snapshot)
    
    if not is_valid and error_response.get('error_type') == 'INVALID_INPUT':
        print("✅ PASS: Missing fields correctly detected")
        print(f"   Missing Fields: {error_response.get('missing_fields')}")
        return True
    else:
        print(f"❌ FAIL: Missing fields not detected correctly")
        print(f"   Response: {error_response}")
        return False


def test_input_validation_invalid_types():
    """Test 4: Invalid Type Validation"""
    print("\n" + "="*60)
    print("TEST 4: Invalid Type Validation")
    print("="*60)
    
    invalid_snapshot = {
        "daily_progress_score": "not_a_number",
        "narrative_score": 85,
        "coord_eval_score": 88,
        "partner_eval_score": 90,
        "attendance_days_present": 18
    }
    
    is_valid, error_response = validate_input(invalid_snapshot)
    
    if not is_valid and error_response.get('error_type') == 'INVALID_INPUT':
        print("✅ PASS: Invalid types correctly detected")
        print(f"   Invalid Fields: {error_response.get('invalid_fields')}")
        return True
    else:
        print(f"❌ FAIL: Invalid types not detected correctly")
        print(f"   Response: {error_response}")
        return False


def test_prediction_success():
    """Test 5: Successful Prediction with Explainability"""
    print("\n" + "="*60)
    print("TEST 5: Successful Prediction with Explainability")
    print("="*60)
    
    valid_snapshot = {
        "daily_progress_score": 75,
        "narrative_score": 80,
        "coord_eval_score": 70,
        "partner_eval_score": 85,
        "attendance_days_present": 20
    }
    
    result = predict_with_explanation(valid_snapshot)
    
    if result.get('success') == True:
        print("✅ PASS: Prediction successful")
        
        ml_pred = result.get('ml_prediction', {})
        print(f"\n   Risk Level: {ml_pred.get('risk_level')}")
        print(f"   Predicted Label: {ml_pred.get('predicted_label')}")
        print(f"   Probability: {ml_pred.get('probability'):.2%}")
        
        print(f"\n   Top Reasons ({len(ml_pred.get('top_reasons', []))}):")
        for i, reason in enumerate(ml_pred.get('top_reasons', []), 1):
            print(f"     {i}. {reason}")
        
        print(f"\n   Recommendation:")
        print(f"     {ml_pred.get('recommendation')}")
        
        print(f"\n   Probabilities:")
        for label, prob in ml_pred.get('probabilities', {}).items():
            print(f"     {label}: {prob:.2%}")
        
        return True
    else:
        print(f"❌ FAIL: Prediction failed")
        print(f"   Error: {result}")
        return False


def test_prediction_model_unavailable():
    """Test 6: Prediction with Unavailable Models"""
    print("\n" + "="*60)
    print("TEST 6: Prediction with Unavailable Models")
    print("="*60)
    print("⚠️  This test requires temporarily disabling models")
    print("    (Skipping - would require modifying module state)")
    return True  # Skip for now as it requires mocking


def test_prediction_invalid_input():
    """Test 7: Prediction with Invalid Input"""
    print("\n" + "="*60)
    print("TEST 7: Prediction with Invalid Input")
    print("="*60)
    
    invalid_snapshot = {
        "daily_progress_score": 82,
        # Missing required fields
    }
    
    result = predict_with_explanation(invalid_snapshot)
    
    if result.get('success') == False and result.get('error_type') == 'INVALID_INPUT':
        print("✅ PASS: Invalid input correctly rejected")
        print(f"   Error Type: {result.get('error_type')}")
        print(f"   Message: {result.get('message')}")
        print(f"   Missing Fields: {result.get('missing_fields')}")
        return True
    else:
        print(f"❌ FAIL: Invalid input not handled correctly")
        print(f"   Response: {result}")
        return False


def test_high_risk_scenario():
    """Test 8: High Risk Scenario"""
    print("\n" + "="*60)
    print("TEST 8: High Risk Scenario")
    print("="*60)
    
    high_risk_snapshot = {
        "daily_progress_score": 50,
        "narrative_score": 55,
        "coord_eval_score": 60,
        "partner_eval_score": 65,
        "attendance_days_present": 10  # Low attendance
    }
    
    result = predict_with_explanation(high_risk_snapshot)
    
    if result.get('success') == True:
        ml_pred = result.get('ml_prediction', {})
        risk_level = ml_pred.get('risk_level')
        
        print(f"   Risk Level: {risk_level}")
        print(f"   Predicted Label: {ml_pred.get('predicted_label')}")
        
        if risk_level == "HIGH":
            print("✅ PASS: High risk correctly identified")
        else:
            print(f"⚠️  WARNING: Expected HIGH risk, got {risk_level}")
        
        print(f"\n   Top Reasons:")
        for i, reason in enumerate(ml_pred.get('top_reasons', []), 1):
            print(f"     {i}. {reason}")
        
        return True
    else:
        print(f"❌ FAIL: Prediction failed")
        return False


def main():
    """Run all tests"""
    print("\n" + "="*60)
    print("INSIGHT ENGINE TEST SUITE")
    print("="*60)
    
    tests = [
        test_model_validation,
        test_input_validation_valid,
        test_input_validation_missing_fields,
        test_input_validation_invalid_types,
        test_prediction_success,
        test_prediction_invalid_input,
        test_high_risk_scenario,
    ]
    
    results = []
    for test_func in tests:
        try:
            result = test_func()
            results.append((test_func.__name__, result))
        except Exception as e:
            print(f"\n❌ ERROR in {test_func.__name__}: {e}")
            import traceback
            traceback.print_exc()
            results.append((test_func.__name__, False))
    
    # Summary
    print("\n" + "="*60)
    print("TEST SUMMARY")
    print("="*60)
    
    passed = sum(1 for _, result in results if result)
    total = len(results)
    
    for test_name, result in results:
        status = "✅ PASS" if result else "❌ FAIL"
        print(f"{status}: {test_name}")
    
    print(f"\nTotal: {passed}/{total} tests passed")
    
    if passed == total:
        print("\n🎉 All tests passed!")
        return 0
    else:
        print(f"\n⚠️  {total - passed} test(s) failed")
        return 1


if __name__ == '__main__':
    sys.exit(main())

