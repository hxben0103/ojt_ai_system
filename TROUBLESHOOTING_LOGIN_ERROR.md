# 🔧 Troubleshooting: "Internal Server Error" on Login

## ✅ Good News!
The error changed from "Connection refused" to "Internal server error" - this means:
- ✅ Your app is connecting to the server correctly
- ✅ Network configuration is working
- ✅ The issue is now on the backend/server side

## 🔍 Common Causes

### 1. Missing .env File (Most Likely)

The backend needs a `.env` file with database credentials.

**Location:** `backend/config/env/.env`

**Check if it exists:**
```powershell
Test-Path "C:\Users\User\Desktop\ojt_ai_system (6)\ojt_ai_system\backend\config\env\.env"
```

**If it doesn't exist, create it with:**
```env
DB_USER=postgres
DB_HOST=localhost
DB_NAME=ojt_ai_system
DB_PASSWORD=your_postgres_password_here
DB_PORT=5432
PORT=3000
NODE_ENV=development
JWT_SECRET=your_jwt_secret_key_here
```

**⚠️ Important:** Replace `your_postgres_password_here` with your actual PostgreSQL password!

---

### 2. Database Not Created

**Check if database exists:**
```sql
-- Connect to PostgreSQL
psql -U postgres

-- List databases
\l

-- Check if ojt_ai_system exists
```

**If it doesn't exist, create it:**
```sql
CREATE DATABASE ojt_ai_system;
```

---

### 3. Database Schema Not Run

**Check if tables exist:**
```sql
-- Connect to database
psql -U postgres -d ojt_ai_system

-- List tables
\dt

-- Should see: users, attendance, evaluations, etc.
```

**If tables don't exist, run schema:**
```bash
cd "C:\Users\User\Desktop\ojt_ai_system (6)\ojt_ai_system\database"
psql -U postgres -d ojt_ai_system -f schema_full.sql
```

---

### 4. Wrong Database Credentials

**Check your .env file:**
- `DB_USER` - Should be `postgres` (or your PostgreSQL username)
- `DB_PASSWORD` - Must match your PostgreSQL password
- `DB_NAME` - Should be `ojt_ai_system`
- `DB_HOST` - Should be `localhost`
- `DB_PORT` - Should be `5432` (default PostgreSQL port)

**Test database connection:**
```powershell
# Test if PostgreSQL is running
Get-Service -Name postgresql*

# Or test connection
psql -U postgres -d ojt_ai_system -c "SELECT 1;"
```

---

### 5. PostgreSQL Not Running

**Check if PostgreSQL service is running:**
```powershell
Get-Service -Name postgresql*
```

**Start PostgreSQL if not running:**
```powershell
Start-Service postgresql-x64-14  # Replace with your version
```

**Or start from Services:**
1. Press `Windows Key + R`
2. Type: `services.msc`
3. Find "PostgreSQL" service
4. Right-click → Start

---

### 6. No Users in Database

**Check if users table has data:**
```sql
psql -U postgres -d ojt_ai_system -c "SELECT COUNT(*) FROM users;"
```

**If count is 0, you need to register a user first:**
- Use the registration screen in the app
- Or insert a test user directly in database

---

## 🔍 How to Debug

### Step 1: Check Backend Server Logs

Look at the terminal where you ran `npm run dev`. You should see error messages like:

```
Login error: Error: connect ECONNREFUSED 127.0.0.1:5432
```
→ Database connection failed

```
Login error: Error: relation "users" does not exist
```
→ Database schema not run

```
Login error: password authentication failed
```
→ Wrong database password

### Step 2: Test Database Connection

**From backend directory:**
```powershell
cd backend
node -e "require('dotenv').config({path:'./config/env/.env'}); const {query} = require('./config/db'); query('SELECT 1').then(() => console.log('✅ DB Connected')).catch(e => console.error('❌ DB Error:', e.message));"
```

### Step 3: Test Health Endpoint

**From phone browser:**
```
http://192.168.184.236:3000/api/health
```

**Expected response:**
```json
{
  "status": "OK",
  "message": "OJT AI System API is running",
  "database": "connected"
}
```

**If database shows "disconnected":**
→ Database connection issue (check .env, PostgreSQL running, credentials)

### Step 4: Check Backend Console

When you try to login, watch the backend terminal. You should see:
- Request logged: `[API] POST /api/auth/login -> ...`
- Error details if something fails

---

## ✅ Quick Fix Checklist

1. **Create .env file** (if missing):
   - Location: `backend/config/env/.env`
   - Copy template from above
   - Update `DB_PASSWORD` with your PostgreSQL password

2. **Verify PostgreSQL is running:**
   ```powershell
   Get-Service postgresql*
   ```

3. **Verify database exists:**
   ```sql
   psql -U postgres -l | findstr ojt_ai_system
   ```

4. **Verify schema is run:**
   ```sql
   psql -U postgres -d ojt_ai_system -c "\dt"
   ```

5. **Test health endpoint:**
   - Phone browser: `http://192.168.184.236:3000/api/health`
   - Should show: `"database": "connected"`

6. **Restart backend server:**
   ```powershell
   # Stop current server (Ctrl+C)
   # Then restart:
   cd backend
   npm run dev
   ```

7. **Try login again**

---

## 🐛 Common Error Messages

### "connect ECONNREFUSED"
- PostgreSQL not running
- Wrong port in .env
- Firewall blocking

### "password authentication failed"
- Wrong password in .env
- Update `DB_PASSWORD` in .env file

### "relation 'users' does not exist"
- Database schema not run
- Run: `psql -U postgres -d ojt_ai_system -f schema_full.sql`

### "database 'ojt_ai_system' does not exist"
- Database not created
- Run: `CREATE DATABASE ojt_ai_system;`

---

## 📝 Step-by-Step Fix

### If .env file is missing:

1. **Create the file:**
   ```powershell
   cd "C:\Users\User\Desktop\ojt_ai_system (6)\ojt_ai_system\backend\config\env"
   # Create .env file (use Notepad or code editor)
   ```

2. **Add this content (update password):**
   ```env
   DB_USER=postgres
   DB_HOST=localhost
   DB_NAME=ojt_ai_system
   DB_PASSWORD=YOUR_ACTUAL_POSTGRES_PASSWORD
   DB_PORT=5432
   PORT=3000
   NODE_ENV=development
   JWT_SECRET=my_secret_key_12345
   ```

3. **Restart backend server:**
   ```powershell
   cd backend
   npm run dev
   ```

4. **Test health endpoint again**

---

**Once the database connection works, login should work!** 🎉

