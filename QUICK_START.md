# Quick Start Guide - Connecting Frontend to Database

## Overview

The Flutter frontend connects to the PostgreSQL database through a Node.js/Express backend API.

```
Flutter App → Backend API → PostgreSQL Database
```

## Step-by-Step Setup

### 1. Database Setup (5 minutes)

```bash
# Create database
psql -U postgres
CREATE DATABASE ojt_ai_system;
\q

# Run schema
psql -U postgres -d ojt_ai_system -f database/schema.sql
```

### 2. Backend Setup (5 minutes)

```bash
cd backend

# Install dependencies
npm install

# Create .env file in backend/config/env/
# Copy the content from backend/config/env/.env.example
# Update database credentials

# Start server
npm run dev
```

Backend should be running at `http://localhost:3000`

### 3. Frontend Setup (2 minutes)

```bash
cd fontend

# Install dependencies
flutter pub get

# Update API URL in lib/core/config.dart
# For web: 'http://localhost:3000/api'
# For Android emulator: 'http://10.0.2.2:3000/api'

# Run app
flutter run -d chrome
```

### 4. Test Connection

```dart
// In your Flutter app
import 'package:your_app/services/auth_service.dart';

// Test login
final response = await AuthService.login(
  email: 'test@example.com',
  password: 'password',
);
```

## Important URLs

- **Backend API**: `http://localhost:3000/api`
- **Health Check**: `http://localhost:3000/api/health`
- **Database**: PostgreSQL on `localhost:5432`

## Common Issues

### Issue: Cannot connect to backend
**Solution**: 
- Check if backend is running: `curl http://localhost:3000/api/health`
- Update API URL in `fontend/lib/core/config.dart`
- For Android emulator, use `10.0.2.2` instead of `localhost`

### Issue: Database connection error
**Solution**:
- Verify PostgreSQL is running
- Check database credentials in `.env`
- Ensure database `ojt_ai_system` exists

### Issue: CORS errors (web)
**Solution**: Backend already has CORS enabled. If issues persist, check browser console for specific errors.

## Next Steps

1. ✅ Database schema created
2. ✅ Backend API running
3. ✅ Frontend connected to backend
4. 🔄 Update login screen to use `AuthService`
5. 🔄 Test all API endpoints
6. 🔄 Implement UI for all features

## Files Created

### Backend
- `backend/config/db.js` - Database connection
- `backend/api/index.js` - Main server
- `backend/api/routes/*.js` - API routes
- `backend/package.json` - Dependencies

### Frontend
- `fontend/lib/core/config.dart` - API configuration
- `fontend/lib/models/*.dart` - Data models
- `fontend/lib/services/*.dart` - API services
- `fontend/lib/utils/example_usage.dart` - Usage examples

### Database
- `database/schema.sql` - Complete database schema

## API Services Available

All services are ready to use:

- `AuthService` - Login, register, logout
- `AttendanceService` - Time in/out, records
- `EvaluationService` - Create, update evaluations
- `OjtService` - OJT records management
- `PredictionService` - AI insights, chatbot logs
- `ReportService` - Generate reports

See `fontend/lib/utils/example_usage.dart` for detailed examples.

