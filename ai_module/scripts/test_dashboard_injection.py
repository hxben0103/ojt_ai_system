import sys
import os
import logging

# Add parent directory to path to import chatbot_handler
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'ollama_integration'))

from chatbot_handler import chatbot_response

# Mock logging to avoid pollution
logging.basicConfig(level=logging.INFO)

def test_student_dashboard():
    print("\n--- Testing Student Dashboard Injection ---")
    data = {
        "hours": {"completed": 150, "required": 300},
        "attendance": {"days_present": 20},
        "daily_tasks": {"completed_tasks": 10},
        "ai_insight": {"score": 85, "risk_level": "LOW"}
    }
    # We use a short message to see if context is injected
    response = chatbot_response("based on my dashboard, how is my progress?", student_data=data)
    answer = response.get("answer", "No answer found")
    print(f"Response: {answer[:200]}...")

def test_coordinator_dashboard():
    print("\n--- Testing Coordinator Dashboard Injection ---")
    data = {
        "total_students": 50,
        "active_ojt": 45,
        "high_risk_students": 5,
        "average_completion": 65.5,
        "average_attendance": 88.0,
        "average_forecast_grade": 82.5
    }
    response = chatbot_response("how many students are at high risk?", student_data=data)
    answer = response.get("answer", "No answer found")
    print(f"Response: {answer[:200]}...")

def test_supervisor_dashboard():
    print("\n--- Testing Supervisor Dashboard Injection ---")
    data = {
        "total_assigned": 10,
        "pending_evaluations": 3,
        "high_risk_students": 1,
        "average_forecast_score": 78.0
    }
    response = chatbot_response("do I have any pending evaluations?", student_data=data)
    answer = response.get("answer", "No answer found")
    print(f"Response: {answer[:200]}...")

def test_admin_dashboard():
    print("\n--- Testing Admin Dashboard Injection ---")
    data = {
        "total_users": 100,
        "active_users": 85,
        "pending_users": 15,
        "coordinator_count": 5
    }
    response = chatbot_response("how many users are waiting for approval?", student_data=data)
    answer = response.get("answer", "No answer found")
    print(f"Response: {answer[:200]}...")

if __name__ == "__main__":
    test_student_dashboard()
    test_coordinator_dashboard()
    test_supervisor_dashboard()
    test_admin_dashboard()
