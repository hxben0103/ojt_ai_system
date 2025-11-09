# Database Schema Analysis - Frontend Requirements

## ✅ Tables That Match Frontend Needs

### 1. **users** table ✅
- Matches: `User` model
- All fields present: user_id, full_name, email, password_hash, role, status, date_created

### 2. **evaluations** table ✅
- Matches: `Evaluation` model
- All fields present: eval_id, student_id, supervisor_id, criteria, total_score, feedback, date_evaluated

### 3. **ai_insights** table ✅
- Matches: `AiInsight` model
- All fields present: insight_id, student_id, model_name, insight_type, result, confidence, created_at

### 4. **chatbot_logs** table ✅
- Matches: `ChatbotLog` model
- All fields present: chat_id, user_id, query, response, model_used, timestamp

### 5. **system_reports** table ✅
- Matches: `SystemReport` model
- All fields present: report_id, report_type, generated_by, content, created_at

## ⚠️ Tables That Need Additional Fields

### 1. **users** table - Missing Student-Specific Fields

**Frontend Requirements (from register_student.dart):**
- `student_id` (separate ID number)
- `course` (e.g., "BSIT", "BSCS")
- `age`
- `gender`
- `contact_number` or `phone`
- `address`
- `profile_photo` (image path/URL)
- `required_hours` (default 300)

**Current Schema:**
```sql
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    role VARCHAR(20) CHECK (role IN ('Admin', 'Coordinator', 'Supervisor', 'Student')),
    status VARCHAR(20) DEFAULT 'Active',
    date_created TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Missing Fields:**
- student_id (for students only)
- course
- age
- gender
- contact_number
- address
- profile_photo
- required_hours

### 2. **attendance** table - Missing Fields for Enhanced DTR

**Frontend Requirements (from student_attendance_screen.dart):**
- `attendance_image` (photo proof)
- `signature` (signature data)
- Multiple time entries:
  - `morning_in` (AM In)
  - `morning_out` (AM Out)
  - `afternoon_in` (PM In)
  - `afternoon_out` (PM Out)
  - `overtime_in` (OT In)
  - `overtime_out` (OT Out)

**Current Schema:**
```sql
CREATE TABLE attendance (
    attendance_id SERIAL PRIMARY KEY,
    student_id INT REFERENCES users(user_id),
    date DATE DEFAULT CURRENT_DATE,
    time_in TIME,
    time_out TIME,
    total_hours NUMERIC(4,2),
    verified BOOLEAN DEFAULT FALSE
);
```

**Missing Fields:**
- attendance_image (TEXT or VARCHAR for path/URL)
- signature (TEXT for signature data)
- morning_in (TIME)
- morning_out (TIME)
- afternoon_in (TIME)
- afternoon_out (TIME)
- overtime_in (TIME)
- overtime_out (TIME)

### 3. **ojt_records** table - Missing Fields

**Frontend Requirements:**
- `required_hours` (total hours required)
- `completed_hours` (calculated from attendance, but could be cached)
- `company_address`
- `company_contact`
- `supervisor_contact`
- `coordinator_contact`

**Current Schema:**
```sql
CREATE TABLE ojt_records (
    record_id SERIAL PRIMARY KEY,
    student_id INT REFERENCES users(user_id),
    company_name VARCHAR(100),
    coordinator_id INT REFERENCES users(user_id),
    supervisor_id INT REFERENCES users(user_id),
    start_date DATE,
    end_date DATE,
    status VARCHAR(20) DEFAULT 'Ongoing'
);
```

**Missing Fields:**
- required_hours (INTEGER)
- company_address (TEXT)
- company_contact (VARCHAR)
- supervisor_contact (VARCHAR)
- coordinator_contact (VARCHAR)

## 📋 Recommended Schema Updates

### Option 1: Add Fields to Existing Tables (Recommended)

```sql
-- Add student-specific fields to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS student_id VARCHAR(50);
ALTER TABLE users ADD COLUMN IF NOT EXISTS course VARCHAR(100);
ALTER TABLE users ADD COLUMN IF NOT EXISTS age INTEGER;
ALTER TABLE users ADD COLUMN IF NOT EXISTS gender VARCHAR(20);
ALTER TABLE users ADD COLUMN IF NOT EXISTS contact_number VARCHAR(20);
ALTER TABLE users ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS profile_photo TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS required_hours INTEGER DEFAULT 300;

-- Add enhanced DTR fields to attendance table
ALTER TABLE attendance ADD COLUMN IF NOT EXISTS attendance_image TEXT;
ALTER TABLE attendance ADD COLUMN IF NOT EXISTS signature TEXT;
ALTER TABLE attendance ADD COLUMN IF NOT EXISTS morning_in TIME;
ALTER TABLE attendance ADD COLUMN IF NOT EXISTS morning_out TIME;
ALTER TABLE attendance ADD COLUMN IF NOT EXISTS afternoon_in TIME;
ALTER TABLE attendance ADD COLUMN IF NOT EXISTS afternoon_out TIME;
ALTER TABLE attendance ADD COLUMN IF NOT EXISTS overtime_in TIME;
ALTER TABLE attendance ADD COLUMN IF NOT EXISTS overtime_out TIME;

-- Add fields to ojt_records table
ALTER TABLE ojt_records ADD COLUMN IF NOT EXISTS required_hours INTEGER DEFAULT 300;
ALTER TABLE ojt_records ADD COLUMN IF NOT EXISTS company_address TEXT;
ALTER TABLE ojt_records ADD COLUMN IF NOT EXISTS company_contact VARCHAR(50);
ALTER TABLE ojt_records ADD COLUMN IF NOT EXISTS supervisor_contact VARCHAR(50);
ALTER TABLE ojt_records ADD COLUMN IF NOT EXISTS coordinator_contact VARCHAR(50);
```

### Option 2: Create Separate Student Profile Table (Better Normalization)

```sql
-- Create student_profiles table for student-specific data
CREATE TABLE student_profiles (
    profile_id SERIAL PRIMARY KEY,
    user_id INT UNIQUE REFERENCES users(user_id),
    student_id VARCHAR(50) UNIQUE,
    course VARCHAR(100),
    age INTEGER,
    gender VARCHAR(20),
    contact_number VARCHAR(20),
    address TEXT,
    profile_photo TEXT,
    required_hours INTEGER DEFAULT 300,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## 🎯 Summary

### ✅ Fully Supported:
- User authentication
- Basic attendance (time in/out)
- Evaluations
- AI insights
- Chatbot logs
- System reports
- OJT records (basic)

### ⚠️ Needs Enhancement:
- **Student profile data** (course, age, gender, contact, address, photo, student_id)
- **Enhanced DTR** (multiple time entries, attendance image, signature)
- **OJT record details** (company contact info, required hours)

### 📝 Recommendation:
Use **Option 1** (ALTER TABLE) for quick implementation, or **Option 2** (separate table) for better database normalization and separation of concerns.

