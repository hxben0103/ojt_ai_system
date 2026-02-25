# OJT AI System - Complete Setup Guide

This guide will walk you through setting up and running the entire OJT AI System step by step.

## 📋 Prerequisites

Before starting, ensure you have the following installed:

1. **PostgreSQL** (v12 or higher)
   - Download from: https://www.postgresql.org/download/
   - Remember your PostgreSQL password

2. **Node.js** (v14 or higher)
   - Download from: https://nodejs.org/
   - Verify: `node --version` and `npm --version`

3. **Python** (v3.8 or higher)
   - Download from: https://www.python.org/downloads/
   - Verify: `python --version`

4. **Flutter SDK** (for frontend)
   - Download from: https://flutter.dev/docs/get-started/install
   - Verify: `flutter --version`

5. **Ollama** (for AI chatbot)
   - Download from: https://ollama.ai/
   - Install and verify: `ollama --version`

---

## 🗄️ Step 1: Database Setup

### 1.1 Create PostgreSQL Database

1. Open PostgreSQL command line or pgAdmin
2. Create the database:

```sql
CREATE DATABASE ojt_ai_system;
```

### 1.2 Run Database Schema

Navigate to the database directory and run the schema:

```bash
cd "C:\Users\User\Desktop\ojt_ai_system (6)\ojt_ai_system\database"
psql -U postgres -d ojt_ai_system -f schema_full.sql
```

Or if you prefer using pgAdmin:
- Open pgAdmin
- Connect to your PostgreSQL server
- Right-click on `ojt_ai_system` database → Query Tool
- Open and execute `schema_full.sql`

### 1.3 Seed Competencies Data

```bash
psql -U postgres -d ojt_ai_system -f seed_competencies.sql
```

Or via pgAdmin Query Tool, execute `seed_competencies.sql`

### 1.4 (Optional) Run Stored Procedures

```bash
psql -U postgres -d ojt_ai_system -f stored_procedures_functions.sql
```

---

## 🔧 Step 2: Backend API Setup (Node.js)

### 2.1 Navigate to Backend Directory

```bash
cd "C:\Users\User\Desktop\ojt_ai_system (6)\ojt_ai_system\backend"
```

### 2.2 Install Dependencies

```bash
npm install
```

### 2.3 Create Environment File

Create a file `.env` in `backend/config/env/` directory:

**Path:** `backend/config/env/.env`

```env
# Database Configuration
DB_USER=postgres
DB_HOST=localhost
DB_NAME=ojt_ai_system
DB_PASSWORD=your_postgres_password_here
DB_PORT=5432

# Server Configuration
PORT=3000
NODE_ENV=development

# JWT Secret (use a strong secret in production)
JWT_SECRET=your_jwt_secret_key_here_change_this_in_production

# API Base URL
API_BASE_URL=http://localhost:3000/api
```

**⚠️ Important:** Replace `your_postgres_password_here` with your actual PostgreSQL password!

### 2.4 Start Backend Server

**Development mode (with auto-reload):**
```bash
npm run dev
```

**Production mode:**
```bash
npm start
```

The backend API will run on `http://localhost:3000`

**✅ Verify:** Open browser to `http://localhost:3000/api/health` - should return a health status.

---

## 🤖 Step 3: AI/ML Server Setup (Python Flask)

### 3.1 Navigate to AI Module Directory

```bash
cd "C:\Users\User\Desktop\ojt_ai_system (6)\ojt_ai_system\ai_module"
```

### 3.2 Install Python Dependencies

```bash
pip install -r requirements.txt
```

This will install:
- Flask
- flask-cors
- numpy
- scikit-learn
- requests
- sentence-transformers
- ollama
- torch

### 3.3 Set Up Ollama Model (for Chatbot)

1. Make sure Ollama is installed and running
2. Pull the required model (check `chatbot_handler.py` or `run_ai.py` for model name):

```bash
ollama pull llama2
# or
ollama pull mistral
# (Check which model your chatbot uses)
```

### 3.4 Start AI Server

```bash
cd "C:\Users\User\Desktop\ojt_ai_system (6)\ojt_ai_system\ai_module\ollama_integration"
python server.py
```

The AI server will run on `http://localhost:5000`

**✅ Verify:** 
- Check terminal for "Running on http://0.0.0.0:5000"
- Test endpoint: `http://localhost:5000/greeting` (should return greeting message)

---

## 📱 Step 4: Flutter Frontend Setup

### 4.1 Navigate to Frontend Directory

```bash
cd "C:\Users\User\Desktop\ojt_ai_system (6)\ojt_ai_system\fontend"
```

### 4.2 Install Flutter Dependencies

```bash
flutter pub get
```

### 4.3 Configure API Endpoints

Check the Flutter code for API configuration. The frontend should connect to:
- **Backend API:** `http://localhost:3000/api`
- **AI Chatbot:** `http://localhost:5000`

If you need to change these, look for configuration files in:
- `lib/services/` directory
- `lib/core/` directory

### 4.4 Run Flutter App

**For Web:**
```bash
flutter run -d chrome
```

**For Android:**
```bash
flutter run
```
(Requires Android Studio/emulator or connected device)

**For Windows:**
```bash
flutter run -d windows
```

**For iOS (Mac only):**
```bash
flutter run -d ios
```

---

## 🚀 Step 5: Running the Complete System

### Start All Services

You need **3 terminal windows** running simultaneously:

#### Terminal 1: Backend API (Node.js)
```bash
cd "C:\Users\User\Desktop\ojt_ai_system (6)\ojt_ai_system\backend"
npm run dev
```

#### Terminal 2: AI Server (Python Flask)
```bash
cd "C:\Users\User\Desktop\ojt_ai_system (6)\ojt_ai_system\ai_module\ollama_integration"
python server.py
```

#### Terminal 3: Flutter Frontend
```bash
cd "C:\Users\User\Desktop\ojt_ai_system (6)\ojt_ai_system\fontend"
flutter run
```

### Verify All Services Are Running

1. **Backend API:** `http://localhost:3000/api/health`
2. **AI Server:** `http://localhost:5000/greeting`
3. **Flutter App:** Should open in browser/emulator

---

## 🧪 Step 6: Testing the System

### 6.1 Test Backend API

```bash
# Health check
curl http://localhost:3000/api/health

# Or use browser:
# http://localhost:3000/api/health
```

### 6.2 Test AI Chatbot

```bash
# Test greeting
curl http://localhost:5000/greeting

# Test chat (POST request)
curl -X POST http://localhost:5000/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello", "session_id": "test123"}'
```

### 6.3 Test Flutter App

1. Open the Flutter app
2. Try logging in (you may need to register first)
3. Test features:
   - Attendance recording
   - Chatbot interaction
   - Daily tasks
   - Dashboard views

---

## 🔍 Troubleshooting

### Database Connection Issues

**Problem:** Backend can't connect to PostgreSQL

**Solutions:**
- Verify PostgreSQL is running: `pg_isready` or check Services
- Check `.env` file has correct credentials
- Verify database `ojt_ai_system` exists
- Check PostgreSQL port (default: 5432)

### Flask Module Not Found

**Problem:** `ModuleNotFoundError: No module named 'flask'`

**Solution:**
```bash
cd "C:\Users\User\Desktop\ojt_ai_system (6)\ojt_ai_system\ai_module"
pip install -r requirements.txt
```

### Ollama Connection Issues

**Problem:** Chatbot can't connect to Ollama

**Solutions:**
- Verify Ollama is running: `ollama list`
- Check if model is downloaded: `ollama pull <model_name>`
- Verify Ollama API is accessible: `http://localhost:11434`

### Port Already in Use

**Problem:** Port 3000 or 5000 already in use

**Solutions:**
- Change port in `.env` file (backend)
- Change port in `server.py` (AI server)
- Or stop the service using that port

### Flutter Build Errors

**Problem:** Flutter dependencies issues

**Solutions:**
```bash
flutter clean
flutter pub get
flutter pub upgrade
```

### CORS Issues

**Problem:** Frontend can't connect to backend/AI server

**Solutions:**
- Verify CORS is enabled in backend (`cors` package installed)
- Check `flask-cors` is installed for AI server
- Verify API URLs in Flutter configuration

---

## 📝 Quick Reference: Service URLs

| Service | URL | Port |
|---------|-----|------|
| Backend API | http://localhost:3000/api | 3000 |
| AI Chatbot Server | http://localhost:5000 | 5000 |
| Flutter App | http://localhost:XXXX (varies) | - |
| PostgreSQL | localhost | 5432 |
| Ollama | http://localhost:11434 | 11434 |

---

## 🎯 Next Steps After Setup

1. **Create Test Users:**
   - Register users via API or directly in database
   - Create students, supervisors, and coordinators

2. **Train AI Model (if needed):**
   - Navigate to `ai_module/scripts/`
   - Run `train_model.py` to train/retrain the model

3. **Test Complete Workflow:**
   - Student logs attendance
   - Student logs daily tasks
   - Supervisor reviews tasks
   - AI generates predictions
   - Coordinator views analytics

---

## 📚 Additional Resources

- **Backend API Docs:** `docs/API_REFERENCE.md`
- **Architecture:** `docs/ARCHITECTURE.md`
- **Database Schema:** `database/schema_full.sql`
- **Implementation Summary:** `IMPLEMENTATION_SUMMARY.md`

---

## ✅ Checklist

Before running the system, ensure:

- [ ] PostgreSQL is installed and running
- [ ] Database `ojt_ai_system` is created
- [ ] Database schema is executed
- [ ] Backend `.env` file is configured
- [ ] Backend dependencies are installed (`npm install`)
- [ ] Python dependencies are installed (`pip install -r requirements.txt`)
- [ ] Ollama is installed and model is pulled
- [ ] Flutter dependencies are installed (`flutter pub get`)
- [ ] All three services can start without errors

---

**Need Help?** Check the troubleshooting section or review the error messages in the terminal windows.

