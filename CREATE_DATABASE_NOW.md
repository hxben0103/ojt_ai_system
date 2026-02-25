# 🚨 URGENT: Create Database to Fix Login Error

## The Problem
Database `ojt_ai_system` doesn't exist → causing "Internal server error" on login.

## ✅ Solution: Create Database (Choose One Method)

### Method 1: Using pgAdmin (Easiest - GUI)

1. **Open pgAdmin** (PostgreSQL administration tool)
   - Usually in Start Menu → PostgreSQL folder

2. **Connect to PostgreSQL server**
   - Enter your PostgreSQL password when prompted

3. **Create Database:**
   - Right-click "Databases" (left panel)
   - Click "Create" → "Database..."
   - Name: `ojt_ai_system`
   - Click "Save"

4. **Run Schema:**
   - Right-click `ojt_ai_system` database
   - Click "Query Tool"
   - Click "Open File" icon
   - Navigate to: `database/schema_full.sql`
   - Click "Execute" (F5 or play button)

5. **Seed Competencies (Optional):**
   - In Query Tool, open: `database/seed_competencies.sql`
   - Execute it

---

### Method 2: Using psql (Command Line)

**Find PostgreSQL installation:**
- Usually at: `C:\Program Files\PostgreSQL\14\bin\` (or version 12, 13, 15, etc.)

**Full path commands:**
```powershell
# Find your PostgreSQL version folder
$pgPath = "C:\Program Files\PostgreSQL\14\bin"  # Change 14 to your version

# Create database
& "$pgPath\psql.exe" -U postgres -c "CREATE DATABASE ojt_ai_system;"

# Run schema
cd "C:\Users\User\Desktop\ojt_ai_system (6)\ojt_ai_system\database"
& "$pgPath\psql.exe" -U postgres -d ojt_ai_system -f schema_full.sql

# Seed competencies
& "$pgPath\psql.exe" -U postgres -d ojt_ai_system -f seed_competencies.sql
```

---

### Method 3: Using SQL Script (If you have access)

Create a file `create_db.sql`:
```sql
CREATE DATABASE ojt_ai_system;
```

Then run it through pgAdmin Query Tool (connected to `postgres` database).

---

## ✅ After Database is Created

### Test Connection:
```powershell
cd "C:\Users\User\Desktop\ojt_ai_system (6)\ojt_ai_system\backend"
node test_db_connection.js
```

Should show: `✅ Database connection successful!`

### Restart Backend:
```powershell
cd backend
npm run dev
```

### Test Login:
Try logging in from your phone - should work now! 🎉

---

## 🔍 Verify It Worked

**Check if database exists:**
- In pgAdmin: Should see `ojt_ai_system` in databases list

**Check if tables exist:**
- In pgAdmin: Expand `ojt_ai_system` → Schemas → public → Tables
- Should see: `users`, `attendance`, `evaluations`, etc.

---

## ⚠️ Common Issues

### "Permission denied"
- Make sure you're using the `postgres` user
- Or a user with CREATE DATABASE privileges

### "Database already exists"
- Good! Database is created
- Just run the schema: `schema_full.sql`

### "psql: command not found"
- Use pgAdmin instead (Method 1)
- Or find PostgreSQL bin folder and use full path

---

**Once database is created and schema is run, the login error should be fixed!**

