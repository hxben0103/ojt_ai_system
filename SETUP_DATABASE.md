# 🗄️ Database Setup - Quick Fix

## Problem Found
The database `ojt_ai_system` does not exist. This is causing the "Internal server error" on login.

## ✅ Quick Fix (3 Steps)

### Step 1: Create the Database

**Option A: Using psql command line**
```powershell
psql -U postgres
```

Then in psql:
```sql
CREATE DATABASE ojt_ai_system;
\q
```

**Option B: Using pgAdmin**
1. Open pgAdmin
2. Connect to PostgreSQL server
3. Right-click "Databases" → "Create" → "Database"
4. Name: `ojt_ai_system`
5. Click "Save"

### Step 2: Run Database Schema

```powershell
cd "C:\Users\User\Desktop\ojt_ai_system (6)\ojt_ai_system\database"
psql -U postgres -d ojt_ai_system -f schema_full.sql
```

**Or using pgAdmin:**
1. Right-click `ojt_ai_system` database
2. Click "Query Tool"
3. Open `schema_full.sql` file
4. Execute (F5)

### Step 3: Seed Competencies (Optional but Recommended)

```powershell
psql -U postgres -d ojt_ai_system -f seed_competencies.sql
```

### Step 4: Verify Database Setup

```powershell
cd "C:\Users\User\Desktop\ojt_ai_system (6)\ojt_ai_system\backend"
node test_db_connection.js
```

Should show: `✅ Database connection successful!`

### Step 5: Restart Backend Server

```powershell
cd backend
npm run dev
```

### Step 6: Test Login Again

Try logging in from your phone - should work now! 🎉

---

## 🔍 Verify Tables Were Created

```sql
psql -U postgres -d ojt_ai_system -c "\dt"
```

Should show tables like:
- users
- attendance
- evaluations
- ojt_records
- etc.

---

## 📝 Quick Command Reference

```powershell
# 1. Create database
psql -U postgres -c "CREATE DATABASE ojt_ai_system;"

# 2. Run schema
cd database
psql -U postgres -d ojt_ai_system -f schema_full.sql

# 3. Seed competencies
psql -U postgres -d ojt_ai_system -f seed_competencies.sql

# 4. Test connection
cd ../backend
node test_db_connection.js
```

---

**After database is created and schema is run, login should work!**

