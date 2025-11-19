# OJT AI System - API Reference

This document describes the RESTful API endpoints for the OJT AI System.

**Base URL**: `http://localhost:3000/api` (development)

---

## Authentication

### POST /api/auth/register

Register a new user account.

**Request Body**:
```json
{
  "full_name": "John Doe",
  "email": "john@example.com",
  "password": "password123",
  "role": "Student",
  "student_id": "2023-001",
  "course": "Computer Science",
  "age": 20,
  "gender": "Male",
  "contact_number": "+1234567890",
  "address": "123 Main St",
  "required_hours": 300
}
```

**Response** (201 Created):
```json
{
  "message": "User registered successfully",
  "user": {
    "user_id": 1,
    "full_name": "John Doe",
    "email": "john@example.com",
    "role": "Student",
    "status": "Pending"
  }
}
```

**Response** (400 Bad Request):
```json
{
  "error": "Missing required fields"
}
```

---

### POST /api/auth/login

Authenticate user and receive JWT token.

**Request Body**:
```json
{
  "email": "john@example.com",
  "password": "password123"
}
```

**Response** (200 OK):
```json
{
  "message": "Login successful",
  "user": {
    "user_id": 1,
    "full_name": "John Doe",
    "email": "john@example.com",
    "role": "Student",
    "status": "Active"
  },
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
}
```

**Response** (401 Unauthorized):
```json
{
  "error": "Invalid email or password"
}
```

---

### GET /api/auth/profile

Get current user profile (requires authentication).

**Headers**:
```
Authorization: Bearer <token>
```

**Response** (200 OK):
```json
{
  "user": {
    "user_id": 1,
    "full_name": "John Doe",
    "email": "john@example.com",
    "role": "Student"
  }
}
```

---

## Attendance

### POST /api/attendance/time-in

Record student time-in.

**Request Body**:
```json
{
  "student_id": 1,
  "time_in": "08:00:00",
  "attendance_image": "base64_encoded_image"
}
```

**Response** (201 Created):
```json
{
  "message": "Time-in recorded successfully",
  "attendance": {
    "attendance_id": 1,
    "student_id": 1,
    "date": "2024-01-15",
    "time_in": "08:00:00"
  }
}
```

---

### POST /api/attendance/time-out

Record student time-out.

**Request Body**:
```json
{
  "student_id": 1,
  "time_out": "17:00:00"
}
```

**Response** (200 OK):
```json
{
  "message": "Time-out recorded successfully",
  "attendance": {
    "attendance_id": 1,
    "total_hours": 8.5
  }
}
```

---

### GET /api/attendance/summary/:studentId

Get attendance summary for a student.

**Response** (200 OK):
```json
{
  "total_hours_completed": 120.5,
  "days_present": 15,
  "last_duty_date": "2024-01-15",
  "required_hours": 300
}
```

---

### GET /api/attendance

Get all attendance records (with optional filters).

**Query Parameters**:
- `student_id` (optional): Filter by student ID
- `date` (optional): Filter by date (YYYY-MM-DD)

**Response** (200 OK):
```json
{
  "attendance": [
    {
      "attendance_id": 1,
      "student_id": 1,
      "date": "2024-01-15",
      "time_in": "08:00:00",
      "time_out": "17:00:00",
      "total_hours": 8.5
    }
  ]
}
```

---

## Evaluations

### POST /api/evaluation

Create a new evaluation.

**Request Body**:
```json
{
  "student_id": 1,
  "supervisor_id": 2,
  "criteria": {
    "Punctuality": 90,
    "Work Quality": 85,
    "Communication": 88
  },
  "total_score": 87.67,
  "feedback": "Excellent performance",
  "evaluation_period_start": "2024-01-01",
  "evaluation_period_end": "2024-01-31"
}
```

**Response** (201 Created):
```json
{
  "message": "Evaluation created successfully",
  "evaluation": {
    "eval_id": 1,
    "student_id": 1,
    "total_score": 87.67
  }
}
```

---

### GET /api/evaluation

Get all evaluations (with optional filters).

**Query Parameters**:
- `student_id` (optional): Filter by student ID
- `supervisor_id` (optional): Filter by supervisor ID

**Response** (200 OK):
```json
{
  "evaluations": [
    {
      "eval_id": 1,
      "student_id": 1,
      "supervisor_id": 2,
      "total_score": 87.67,
      "date_evaluated": "2024-01-15T10:00:00Z"
    }
  ]
}
```

---

### GET /api/evaluation/:id

Get evaluation by ID.

**Response** (200 OK):
```json
{
  "evaluation": {
    "eval_id": 1,
    "student_id": 1,
    "criteria": {...},
    "total_score": 87.67
  }
}
```

---

### PUT /api/evaluation/:id

Update an evaluation.

**Request Body**:
```json
{
  "total_score": 90,
  "feedback": "Updated feedback",
  "status": "Approved"
}
```

**Response** (200 OK):
```json
{
  "message": "Evaluation updated successfully",
  "evaluation": {...}
}
```

---

## Predictions

### GET /api/prediction/daily/:studentId

Get daily risk prediction for a student.

**Response** (200 OK):
```json
{
  "student_id": 1,
  "snapshot": {
    "daily_progress_score": 82,
    "narrative_score": 85,
    "coord_eval_score": 88,
    "partner_eval_score": 90,
    "attendance_days_present": 18
  },
  "ai_prediction": {
    "features_used": {...},
    "prediction": {
      "predicted_label": "Good",
      "probability": 0.85,
      "class_probabilities": {
        "Excellent": 0.10,
        "Good": 0.85,
        "Average": 0.05
      },
      "risk_level": "LOW"
    }
  },
  "generated_at": "2024-01-15T10:00:00Z"
}
```

**Response** (503 Service Unavailable):
```json
{
  "error": "AI prediction service unavailable",
  "message": "Cannot connect to Flask AI service"
}
```

---

### GET /api/prediction/insights

Get AI insights (with optional student filter).

**Query Parameters**:
- `student_id` (optional): Filter by student ID

**Response** (200 OK):
```json
{
  "insights": [
    {
      "insight_id": 1,
      "student_id": 1,
      "model_name": "Daily Risk Prediction Ensemble",
      "risk_level": "LOW",
      "confidence": 0.85,
      "created_at": "2024-01-15T10:00:00Z"
    }
  ]
}
```

---

### GET /api/prediction/risk-assessment/:student_id

Get risk assessment for a student.

**Response** (200 OK):
```json
{
  "risk_assessment": {
    "student_id": 1,
    "risk_score": 25,
    "risk_level": "LOW",
    "risk_factors": {...},
    "recommendations": [...]
  }
}
```

---

## Chatbot

### POST /chat (Flask AI Module)

Send message to chatbot.

**Base URL**: `http://localhost:5000` (Flask server)

**Request Body**:
```json
{
  "message": "What are the OJT requirements?"
}
```

**Response** (200 OK):
```json
{
  "response": "The OJT requirements include..."
}
```

---

### POST /api/prediction/chatbot/logs

Save chatbot interaction log.

**Request Body**:
```json
{
  "user_id": 1,
  "query": "What are the OJT requirements?",
  "response": "The OJT requirements include...",
  "model_used": "rule-based"
}
```

**Response** (201 Created):
```json
{
  "message": "Chatbot log saved successfully",
  "log": {
    "chat_id": 1,
    "user_id": 1,
    "query": "What are the OJT requirements?",
    "response": "The OJT requirements include...",
    "model_used": "rule-based",
    "timestamp": "2024-01-15T10:00:00Z"
  }
}
```

**Response** (400 Bad Request):
```json
{
  "error": "Missing required fields: user_id, query, and response are required"
}
```

---

### GET /api/prediction/chatbot/logs

Get chatbot logs (with optional user filter).

**Query Parameters**:
- `user_id` (optional): Filter by user ID

**Response** (200 OK):
```json
{
  "logs": [
    {
      "chat_id": 1,
      "user_id": 1,
      "query": "What are the OJT requirements?",
      "response": "The OJT requirements include...",
      "model_used": "rule-based",
      "timestamp": "2024-01-15T10:00:00Z"
    }
  ]
}
```

---

### GET /api/prediction/chatbot/logs/:userId

Get chatbot logs for a specific user.

**Response** (200 OK):
```json
{
  "logs": [
    {
      "chat_id": 1,
      "user_id": 1,
      "query": "What are the OJT requirements?",
      "response": "The OJT requirements include...",
      "model_used": "rule-based",
      "timestamp": "2024-01-15T10:00:00Z"
    }
  ]
}
```

---

## OJT Records

### POST /api/ojt

Create a new OJT record.

**Request Body**:
```json
{
  "student_id": 1,
  "company_name": "ABC Corporation",
  "coordinator_id": 2,
  "supervisor_id": 3,
  "start_date": "2024-01-01",
  "end_date": "2024-06-30",
  "required_hours": 300
}
```

**Response** (201 Created):
```json
{
  "message": "OJT record created successfully",
  "ojt_record": {...}
}
```

---

### GET /api/ojt

Get OJT records (with optional filters).

**Query Parameters**:
- `student_id` (optional)
- `coordinator_id` (optional)
- `supervisor_id` (optional)

**Response** (200 OK):
```json
{
  "ojt_records": [
    {
      "record_id": 1,
      "student_id": 1,
      "company_name": "ABC Corporation",
      "status": "Ongoing"
    }
  ]
}
```

---

## Reports

### POST /api/reports

Generate a system report.

**Request Body**:
```json
{
  "report_type": "attendance_summary",
  "report_period_start": "2024-01-01",
  "report_period_end": "2024-01-31"
}
```

**Response** (201 Created):
```json
{
  "message": "Report generated successfully",
  "report": {
    "report_id": 1,
    "report_type": "attendance_summary",
    "status": "Generated"
  }
}
```

---

### GET /api/reports

Get all reports.

**Response** (200 OK):
```json
{
  "reports": [
    {
      "report_id": 1,
      "report_type": "attendance_summary",
      "status": "Generated",
      "created_at": "2024-01-15T10:00:00Z"
    }
  ]
}
```

---

## Health Check

### GET /api/health

Check API and database connectivity.

**Response** (200 OK):
```json
{
  "status": "OK",
  "message": "OJT AI System API is running",
  "database": "connected"
}
```

**Response** (503 Service Unavailable):
```json
{
  "status": "ERROR",
  "message": "OJT AI System API is running but database connection failed",
  "database": "disconnected"
}
```

---

## Error Responses

All endpoints may return the following error responses:

### 400 Bad Request
```json
{
  "error": "Validation error message"
}
```

### 401 Unauthorized
```json
{
  "error": "Authentication required"
}
```

### 403 Forbidden
```json
{
  "error": "Access denied"
}
```

### 404 Not Found
```json
{
  "error": "Resource not found"
}
```

### 500 Internal Server Error
```json
{
  "error": "Internal server error",
  "message": "Detailed error message (development only)"
}
```

### 503 Service Unavailable
```json
{
  "error": "Service unavailable",
  "message": "Service description"
}
```

---

## Authentication

Most endpoints require authentication via JWT token in the Authorization header:

```
Authorization: Bearer <token>
```

Tokens are obtained via `/api/auth/login` and expire after 7 days.

---

## Rate Limiting

Currently, no rate limiting is implemented. Consider adding rate limiting for production deployments.

---

## Response Time Logging

All API requests are logged with response times:
- 🟢 Green: Success (2xx)
- 🟡 Yellow: Client Error (4xx)
- 🔴 Red: Server Error (5xx)

Example log output:
```
🟢 [API] GET /api/attendance/summary/1 -> 200 (45ms)
```

---

## Notes

- All timestamps are in ISO 8601 format (UTC)
- Date fields use YYYY-MM-DD format
- Time fields use HH:MM:SS format
- All IDs are integers
- Scores and numeric values use appropriate precision (typically 2 decimal places)

