import requests
import json

def test_predict():
    url = "http://127.0.0.1:5000/predict"
    payload = {
        "total_hours_completed": 150.0,
        "required_hours": 300,
        "attendance_rate": 75.0,
        "total_tasks_logged": 20,
        "weekly_progress_grade": 85.0,
        "narrative_report_grade": 80.0,
        "coordinator_eval_grade": 88.0,
        "supervisor_eval_grade": 90.0,
        "has_weekly_progress_grade": 1,
        "has_narrative_report_grade": 1,
        "has_coordinator_eval_grade": 1,
        "has_supervisor_eval_grade": 1
    }
    
    try:
        print(f"Sending request to {url}...")
        response = requests.post(url, json=payload, timeout=200)
        print(f"Status Code: {response.status_code}")
        print("Response Body:")
        print(json.dumps(response.json(), indent=2))
    except Exception as e:
        print(f"Error: {e}")

def test_ollama():
    url = "http://127.0.0.1:11434/api/generate"
    payload = {
        "model": "gemma2:2b",
        "prompt": "Hello, how are you?",
        "stream": False
    }
    
    try:
        print(f"Sending request to Ollama ({url})...")
        response = requests.post(url, json=payload, timeout=60)
        print(f"Status Code: {response.status_code}")
        if response.status_code == 200:
            print("Ollama is responding.")
            # print(response.json().get("response"))
        else:
            print(f"Ollama Error: {response.text}")
    except Exception as e:
        print(f"Ollama Connection Error: {e}")

if __name__ == "__main__":
    print("--- Testing Ollama directly ---")
    test_ollama()
    print("\n--- Testing API /predict ---")
    test_predict()
