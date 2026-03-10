import requests
import json

url = "http://localhost:5000/predict"
payload = {
  "total_hours_completed": 150.0,
  "required_hours": 300,
  "attendance_rate": 75.0,
  "late_count": 2,
  "absent_count": 5,
  "hours_completed_ratio": 0.5,
  "total_tasks_logged": 20,
  "total_task_hours": 80.0,
  "number_of_distinct_competencies": 5,
  "hours_software_development": 40.0,
  "inside_geofence": True,
  "distance_m": 12.0,
  "accuracy_m": 15.0,
  "trust_flags": "mock_location",
  "has_photo": False,
  "recent_flags_count": 1,
  "trend_status": "declining",
  "trend_reason": "Hours dropped by 20%"
}

try:
    response = requests.post(url, json=payload)
    print("Status Code:", response.status_code)
    print("Response JSON:")
    print(json.dumps(response.json(), indent=2))
except Exception as e:
    print(f"Error: {e}")
