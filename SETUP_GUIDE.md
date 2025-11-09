# OJT AI System - Setup Guide

## Database Setup

### 1. Install PostgreSQL
- Download and install PostgreSQL from https://www.postgresql.org/download/
- Create a new database named `ojt_ai_system`

### 2. Run Database Schema
```bash
# Connect to PostgreSQL and create the database
psql -U postgres
CREATE DATABASE ojt_ai_system;

# Run the schema file
psql -U postgres -d ojt_ai_system -f database/schema.sql
```

### 3. Verify Database Setup
```sql
-- Check if tables are created
\dt

-- Check if views are created
\dv
```

## Backend Setup

### 1. Install Dependencies
```bash
cd backend
npm install
```

### 2. Configure Environment Variables
Create a `.env` file in `backend/config/env/` directory:

```env
# Database Configuration
DB_USER=postgres
DB_HOST=localhost
DB_NAME=ojt_ai_system
DB_PASSWORD=your_password_here
DB_PORT=5432

# Server Configuration
PORT=3000
NODE_ENV=development

# JWT Secret
JWT_SECRET=your_jwt_secret_key_here

# API Base URL
API_BASE_URL=http://localhost:3000/api
```

### 3. Start Backend Server
```bash
# Development mode (with auto-reload)
npm run dev

# Production mode
npm start
```

The backend API will be available at `http://localhost:3000/api`

### 4. Test Backend Connection
```bash
# Health check
curl http://localhost:3000/api/health
```

## Frontend Setup

### 1. Install Dependencies
```bash
cd fontend
flutter pub get
```

### 2. Configure API URL
Edit `fontend/lib/core/config.dart` and update the `baseUrl`:

```dart
// For web development
static const String baseUrl = 'http://localhost:3000/api';

// For Android emulator
static const String baseUrl = 'http://10.0.2.2:3000/api';

// For iOS simulator
static const String baseUrl = 'http://localhost:3000/api';

// For physical device (replace with your computer's IP)
static const String baseUrl = 'http://192.168.1.100:3000/api';
```

### 3. Run Flutter App
```bash
# Web
flutter run -d chrome

# Android
flutter run -d android

# iOS
flutter run -d ios
```

## Connecting Frontend to Database

The connection is handled through the backend API:

1. **Frontend (Flutter)** → Makes HTTP requests to → **Backend API (Node.js/Express)**
2. **Backend API** → Connects to → **PostgreSQL Database**

### API Endpoints

#### Authentication
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - Login user
- `GET /api/auth/profile` - Get user profile
- `GET /api/auth/users` - Get all users (Admin only)

#### Attendance
- `GET /api/attendance` - Get all attendance records
- `POST /api/attendance/time-in` - Record time in
- `PUT /api/attendance/time-out` - Record time out
- `GET /api/attendance/summary` - Get attendance summary
- `PUT /api/attendance/verify/:id` - Verify attendance

#### Evaluations
- `GET /api/evaluation` - Get all evaluations
- `POST /api/evaluation` - Create evaluation
- `PUT /api/evaluation/:id` - Update evaluation
- `GET /api/evaluation/:id` - Get evaluation by ID

#### Predictions & AI Insights
- `GET /api/prediction/insights` - Get AI insights
- `POST /api/prediction/insights` - Create AI insight
- `GET /api/prediction/performance` - Get performance predictions
- `GET /api/prediction/chatbot/logs` - Get chatbot logs
- `POST /api/prediction/chatbot/logs` - Save chatbot log

#### Reports
- `GET /api/reports` - Get all reports
- `POST /api/reports` - Create report
- `GET /api/reports/:id` - Get report by ID
- `GET /api/reports/ojt/records` - Get OJT records
- `POST /api/reports/ojt/records` - Create OJT record

## Usage Example

### In Flutter App

```dart
import 'package:your_app/services/auth_service.dart';
import 'package:your_app/services/attendance_service.dart';

// Login
final response = await AuthService.login(
  email: 'student@example.com',
  password: 'password123',
);

// Get attendance records
final attendance = await AttendanceService.getAttendance(
  studentId: 1,
);
```

## Troubleshooting

### Database Connection Issues
- Verify PostgreSQL is running
- Check database credentials in `.env` file
- Ensure database `ojt_ai_system` exists

### Backend Connection Issues
- Verify backend server is running on port 3000
- Check CORS settings if accessing from web
- Verify environment variables are set correctly

### Frontend Connection Issues
- Update API URL in `config.dart` for your platform
- For physical devices, use your computer's local IP address
- Check network connectivity
- Verify backend server is accessible from your device

### CORS Issues (Web)
If you encounter CORS errors when running Flutter web, make sure the backend has CORS enabled (already configured in `backend/api/index.js`).

## Project Structure

```
OJT_AI_System/
├── backend/              # Node.js/Express API
│   ├── api/             # API routes
│   ├── config/          # Database configuration
│   └── package.json
├── fontend/             # Flutter app
│   ├── lib/
│   │   ├── core/        # Configuration
│   │   ├── models/      # Data models
│   │   ├── services/    # API services
│   │   └── screens/     # UI screens
│   └── pubspec.yaml
└── database/            # Database schema
    └── schema.sql
```

## Next Steps

1. Set up the database and run the schema
2. Configure backend environment variables
3. Start the backend server
4. Update frontend API URL
5. Run the Flutter app
6. Test the connection by logging in

