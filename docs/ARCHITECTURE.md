# OJT AI System - Architecture Documentation

## Overview

The OJT AI System is an intelligent On-the-Job Training monitoring platform that combines Flutter frontend, Node.js backend, PostgreSQL database, and Python AI module with Flask chatbot. The system provides comprehensive OJT management, real-time risk prediction, and AI-powered assistance for students, coordinators, supervisors, and administrators.

### Technology Stack

- **Frontend**: Flutter (Dart) - Cross-platform mobile and web application
- **Backend**: Node.js (Express.js) - RESTful API server
- **Database**: PostgreSQL - Relational database management
- **AI Module**: Python (Flask) - Machine learning models and chatbot
- **Authentication**: JWT (JSON Web Tokens)

---

## System Architecture

```
┌─────────────────┐
│  Flutter App    │
│  (Frontend)     │
└────────┬────────┘
         │ HTTP/REST
         │
┌────────▼────────┐
│  Node.js API    │
│  (Backend)      │
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
┌───▼───┐  ┌─▼────────┐
│PostgreSQL│ │Flask AI │
│ Database │ │ Module  │
└─────────┘ └─────────┘
```

---

## Frontend (Flutter)

### Main Roles

The system supports four distinct user roles, each with tailored dashboards and functionalities:

1. **Admin**: System administration, user management, approvals
2. **Coordinator**: Student monitoring, performance analysis, OJT record management
3. **Supervisor**: Student evaluation, feedback, attendance verification
4. **Student**: Attendance tracking, progress viewing, chatbot interaction

### Key Screens

#### Dashboards
- **Admin Dashboard**: User approvals, system reports, overall monitoring
- **Coordinator Dashboard**: Student tasks & attendance tracking, performance analysis, supervisor feedback review
- **Supervisor Dashboard**: Assigned students monitoring, evaluation forms
- **Student Dashboard**: Personal attendance, progress reports, chatbot access

#### Core Features
- **Attendance Management**: Time-in/time-out with image capture, DTR viewing
- **Evaluation System**: Multi-criteria evaluations with scoring
- **AI Chatbot**: Rule-based assistant for OJT-related queries
- **Risk Prediction**: Daily AI-powered risk assessment for students
- **Reports**: Automated report generation and analytics

### Services Layer

The Flutter app uses a service-oriented architecture:

- `AuthService`: Authentication and user management
- `AttendanceService`: Attendance operations
- `EvaluationService`: Evaluation CRUD operations
- `OjtService`: OJT record management
- `PredictionService`: AI predictions and chatbot logging
- `ReportService`: Report generation

---

## Backend (Node.js)

### API Structure

The backend is organized into modular route files:

#### `/api/auth` (auth.js)
- User registration and login
- JWT token generation and validation
- User profile management
- Account approval workflow

#### `/api/attendance` (attendance.js)
- Time-in/time-out operations
- Attendance record retrieval
- Attendance summary and statistics
- Daily time record (DTR) management

#### `/api/evaluation` (evaluation.js)
- Evaluation creation and updates
- Evaluation retrieval by student/supervisor
- Evaluation approval workflow
- Criteria-based scoring

#### `/api/prediction` (prediction.js)
- Daily risk prediction for students
- AI insights retrieval
- Chatbot log management
- Performance predictions
- Risk assessment endpoints

#### `/api/ojt` (ojt.js)
- OJT record creation and management
- Student-coordinator-supervisor assignments
- OJT status tracking

#### `/api/reports` (reports.js)
- System report generation
- Report retrieval and management

### Database Integration

The backend uses PostgreSQL with:
- Connection pooling via `pg` library
- Parameterized queries for security
- Stored procedures for complex operations
- Transaction support for data integrity

### AI Module Communication

The backend communicates with the Python Flask AI module via HTTP:
- **Daily Predictions**: `POST /predict` - Sends student snapshot, receives risk prediction
- **Chatbot**: Direct Flutter-to-Flask communication (with backend logging)

### Middleware

- **CORS**: Cross-origin resource sharing configuration
- **Body Parser**: JSON and URL-encoded body parsing
- **Response Time Logging**: Tracks API response times for performance monitoring
- **Error Logging**: Captures critical errors to `api_error_logs` table

---

## Database (PostgreSQL)

### Main Tables

#### `users`
Stores all system users (Admin, Coordinator, Supervisor, Student) with role-based access control.

#### `ojt_records`
Links students to coordinators and supervisors, tracks OJT periods, company information, and status.

#### `attendance`
Daily attendance records with time-in/time-out, total hours, verification status, and images.

#### `evaluations`
Multi-criteria evaluations with scores, feedback, evaluation periods, and approval workflow.

#### `ai_insights`
Stores AI predictions, risk assessments, and model outputs with confidence scores and timestamps.

#### `chatbot_logs`
Logs all chatbot interactions (user queries and bot responses) for analytics and improvement.

#### `api_error_logs`
Tracks API errors for system reliability monitoring and debugging.

### Relationships

- Users → OJT Records (one-to-many)
- Users → Attendance (one-to-many)
- Users → Evaluations (one-to-many, as student and supervisor)
- Users → AI Insights (one-to-many)
- Users → Chatbot Logs (one-to-many)

### Stored Procedures

The database includes stored procedures for:
- Performance prediction generation
- Risk score calculation
- Batch prediction processing
- Data validation and business logic enforcement

---

## AI Module (Python Flask)

### Trained Models

The system uses an ensemble of three machine learning models:

1. **Logistic Regression**: Linear classification model
2. **Random Forest**: Tree-based ensemble model
3. **Naive Bayes**: Probabilistic classification model

**Ensemble Approach**: Weighted averaging (0.4, 0.4, 0.2) of model probabilities for final prediction.

### Model Artifacts

- `logistic_regression.pkl`: Trained logistic regression model
- `random_forest.pkl`: Trained random forest model
- `naive_bayes.pkl`: Trained naive bayes model
- `scaler.pkl`: Feature scaling transformer
- `label_encoder.pkl`: Label encoding for target classes
- `feature_names.pkl`: Ordered list of feature names

### Features

The model uses five key features:
1. Weekly Progress Report (Score)
2. Practicum Narrative Report (Score)
3. Practicum Coordinator Evaluation (Score)
4. Practicum Partner Supervisor Evaluation (Score)
5. Attendance (Days Present out of 25)

### Endpoints

#### `/predict` (POST)
- **Input**: Daily student snapshot (scores, attendance)
- **Output**: Risk prediction with:
  - `predicted_label`: Predicted performance category
  - `probability`: Confidence score
  - `class_probabilities`: Probability distribution across all classes
  - `risk_level`: HIGH / MEDIUM / LOW

#### `/chat` (POST)
- **Input**: User message
- **Output**: Rule-based chatbot response
- **Logic**: Pattern matching and keyword-based responses for OJT-related queries

### Insight Engine

The `insight_engine.py` module:
- Loads all trained models at startup
- Maps daily snapshots to model features
- Performs ensemble prediction
- Maps predictions to risk levels (HIGH/MEDIUM/LOW)

---

## Chatbot

### Architecture

The chatbot uses a **rule-based approach** with pattern matching:

- **Location**: `ai_module/ollama_integration/chatbot_handler.py`
- **Logic**: Keyword-based response generation
- **Topics**: JRMSU information, OJT processes, grading, competencies, report formats

### Logging

Every chatbot interaction is logged:
1. **Flutter** → Calls Flask `/chat` endpoint
2. **Flutter** → Logs interaction to Node.js `/api/prediction/chatbot/logs`
3. **Node.js** → Stores in `chatbot_logs` table with:
   - User ID
   - Query text
   - Response text
   - Model used (rule-based)
   - Timestamp

### Analytics

Chatbot logs enable:
- Common question analysis
- Usage frequency tracking
- Problem identification
- System improvement insights

---

## Data Flow

### Daily Risk Prediction Flow

```
1. Coordinator/Student requests prediction
   ↓
2. Flutter calls: GET /api/prediction/daily/:studentId
   ↓
3. Node.js builds daily snapshot from PostgreSQL:
   - Coordinator evaluations
   - Partner evaluations
   - Narrative scores
   - Attendance statistics
   ↓
4. Node.js calls: POST Flask /predict with snapshot
   ↓
5. Flask AI Module:
   - Maps snapshot to features
   - Runs ensemble prediction
   - Returns risk level and probabilities
   ↓
6. Node.js stores result in ai_insights table
   ↓
7. Node.js returns prediction to Flutter
   ↓
8. Flutter displays risk badge on dashboard
```

### Chatbot Interaction Flow

```
1. User types message in Flutter
   ↓
2. Flutter calls: POST Flask /chat
   ↓
3. Flask processes with rule-based logic
   ↓
4. Flask returns response
   ↓
5. Flutter displays response
   ↓
6. Flutter logs interaction: POST /api/prediction/chatbot/logs
   ↓
7. Node.js stores in chatbot_logs table
```

---

## Security

- **Authentication**: JWT tokens with 7-day expiration
- **Password Hashing**: bcrypt with salt rounds
- **SQL Injection Prevention**: Parameterized queries
- **CORS**: Configured for allowed origins
- **Role-Based Access**: User roles enforced at API level

---

## Performance & Reliability

### Monitoring

- **Response Time Logging**: All API requests log duration
- **Error Logging**: Critical errors stored in `api_error_logs`
- **Status Codes**: Color-coded logging (🟢 success, 🟡 warning, 🔴 error)

### Optimization

- **Database Indices**: On frequently queried columns (user_id, timestamps)
- **Connection Pooling**: Efficient database connection management
- **Async Operations**: Non-blocking I/O for better performance

---

## Future Enhancements

- Integration with external LLM APIs for enhanced chatbot
- Real-time notifications for risk alerts
- Advanced analytics dashboard
- Mobile push notifications
- Export capabilities for reports

---

## Conclusion

The OJT AI System provides a comprehensive, scalable solution for managing On-the-Job Training programs with intelligent risk prediction and user-friendly interfaces. The modular architecture allows for easy maintenance and future enhancements.

