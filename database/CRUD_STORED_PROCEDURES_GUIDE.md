# CRUD Stored Procedures Guide for REST API

## Overview

Complete CRUD (Create, Read, Update, Delete) operations are now available as stored procedures for all main entities. These provide:
- ✅ Built-in validation
- ✅ Consistent error handling
- ✅ JSONB responses
- ✅ Business logic enforcement

---

## 📋 Available CRUD Functions

### **Users** (4 functions)
- `create_user(...)` - Create user with validation
- `get_user(user_id)` - Get user by ID
- `update_user(...)` - Update user fields
- `delete_user(user_id)` - Soft delete (sets status to Inactive)

### **OJT Records** (4 functions)
- `create_ojt_record(...)` - Create with validation
- `get_ojt_record(record_id)` - Get by ID
- `update_ojt_record(...)` - Update fields
- `delete_ojt_record(record_id)` - Delete record

### **Attendance** (4 functions)
- `create_attendance(...)` - Create with validation
- `get_attendance(attendance_id)` - Get by ID
- `update_attendance(...)` - Update times
- `delete_attendance(attendance_id)` - Delete record

### **Evaluations** (4 functions)
- `create_evaluation(...)` - Create with score validation
- `get_evaluation(eval_id)` - Get by ID
- `update_evaluation(...)` - Update fields
- `delete_evaluation(eval_id)` - Delete record

### **AI Insights** (3 functions)
- `create_ai_insight(...)` - Create insight
- `get_ai_insight(insight_id)` - Get by ID
- `delete_ai_insight(insight_id)` - Delete insight

### **System Reports** (3 functions)
- `create_system_report(...)` - Create report
- `get_system_report(report_id)` - Get by ID
- `delete_system_report(report_id)` - Delete report

---

## 🔧 Usage Examples

### **1. Users CRUD**

#### Create User
```javascript
// POST /api/users
router.post('/', async (req, res) => {
  const { full_name, email, password, role, student_id, course } = req.body;
  
  // Hash password first
  const password_hash = await bcrypt.hash(password, 10);
  
  const result = await query(
    'SELECT create_user($1, $2, $3, $4, $5, $6, $7) as result',
    [full_name, email, password_hash, role, student_id, course, null]
  );
  
  const response = result.rows[0].result;
  
  if (response.success) {
    res.status(201).json(response);
  } else {
    res.status(400).json(response);
  }
});
```

#### Get User
```javascript
// GET /api/users/:id
router.get('/:id', async (req, res) => {
  const result = await query('SELECT get_user($1) as user', [req.params.id]);
  const user = result.rows[0].user;
  
  if (user.error) {
    return res.status(404).json(user);
  }
  
  res.json({ user });
});
```

#### Update User
```javascript
// PUT /api/users/:id
router.put('/:id', async (req, res) => {
  const { full_name, email, role, status, course } = req.body;
  
  const result = await query(
    'SELECT update_user($1, $2, $3, $4, $5, NULL, $6, NULL) as result',
    [req.params.id, full_name, email, role, status, course]
  );
  
  const response = result.rows[0].result;
  
  if (response.success) {
    res.json(response);
  } else {
    res.status(400).json(response);
  }
});
```

#### Delete User
```javascript
// DELETE /api/users/:id
router.delete('/:id', async (req, res) => {
  const result = await query('SELECT delete_user($1) as result', [req.params.id]);
  const response = result.rows[0].result;
  
  if (response.success) {
    res.json(response);
  } else {
    res.status(404).json(response);
  }
});
```

---

### **2. OJT Records CRUD**

#### Create OJT Record
```javascript
// POST /api/ojt-records
router.post('/', async (req, res) => {
  const {
    student_id, company_name, coordinator_id, supervisor_id,
    start_date, end_date, required_hours, company_address, company_contact
  } = req.body;
  
  const result = await query(
    'SELECT create_ojt_record($1, $2, $3, $4, $5, $6, $7, $8, $9) as result',
    [student_id, company_name, coordinator_id, supervisor_id,
     start_date, end_date, required_hours, company_address, company_contact]
  );
  
  const response = result.rows[0].result;
  
  if (response.success) {
    res.status(201).json(response);
  } else {
    res.status(400).json(response);
  }
});
```

#### Get OJT Record
```javascript
// GET /api/ojt-records/:id
router.get('/:id', async (req, res) => {
  const result = await query('SELECT get_ojt_record($1) as record', [req.params.id]);
  const record = result.rows[0].record;
  
  if (record.error) {
    return res.status(404).json(record);
  }
  
  res.json({ record });
});
```

---

### **3. Attendance CRUD**

#### Create Attendance
```javascript
// POST /api/attendance
router.post('/', async (req, res) => {
  const {
    student_id, date, time_in, time_out,
    morning_in, morning_out, afternoon_in, afternoon_out
  } = req.body;
  
  const result = await query(
    'SELECT create_attendance($1, $2, $3, $4, $5, $6, $7, $8) as result',
    [student_id, date, time_in, time_out,
     morning_in, morning_out, afternoon_in, afternoon_out]
  );
  
  const response = result.rows[0].result;
  
  if (response.success) {
    res.status(201).json(response);
  } else {
    res.status(400).json({ errors: response.errors });
  }
});
```

#### Update Attendance (Time Out)
```javascript
// PUT /api/attendance/:id/time-out
router.put('/:id/time-out', async (req, res) => {
  const { time_out } = req.body;
  
  const result = await query(
    'SELECT update_attendance($1, NULL, $2, NULL, NULL, NULL, NULL) as result',
    [req.params.id, time_out]
  );
  
  const response = result.rows[0].result;
  
  if (response.success) {
    res.json(response);
  } else {
    res.status(404).json(response);
  }
});
```

---

### **4. Evaluations CRUD**

#### Create Evaluation
```javascript
// POST /api/evaluations
router.post('/', async (req, res) => {
  const {
    student_id, supervisor_id, criteria, total_score,
    feedback, evaluation_period_start, evaluation_period_end
  } = req.body;
  
  const result = await query(
    'SELECT create_evaluation($1, $2, $3, $4, $5, $6, $7) as result',
    [student_id, supervisor_id, JSON.stringify(criteria), total_score,
     feedback, evaluation_period_start, evaluation_period_end]
  );
  
  const response = result.rows[0].result;
  
  if (response.success) {
    res.status(201).json(response);
  } else {
    res.status(400).json(response);
  }
});
```

#### Approve Evaluation
```javascript
// PUT /api/evaluations/:id/approve
router.put('/:id/approve', async (req, res) => {
  const result = await query(
    'SELECT update_evaluation($1, NULL, NULL, NULL, $2) as result',
    [req.params.id, 'Approved']
  );
  
  // Trigger will auto-generate prediction when status = 'Approved'
  res.json(result.rows[0].result);
});
```

---

### **5. AI Insights CRUD**

#### Create AI Insight
```javascript
// POST /api/prediction/insights
router.post('/insights', async (req, res) => {
  const { student_id, model_name, insight_type, result, confidence, input_data } = req.body;
  
  const dbResult = await query(
    'SELECT create_ai_insight($1, $2, $3, $4, $5, $6) as result',
    [student_id, model_name, insight_type, JSON.stringify(result), confidence, JSON.stringify(input_data)]
  );
  
  res.status(201).json(dbResult.rows[0].result);
});
```

---

## 📊 Response Format

All CRUD functions return JSONB with consistent format:

### **Success Response**
```json
{
  "success": true,
  "user_id": 123,
  "user": {
    "user_id": 123,
    "full_name": "John Doe",
    "email": "john@example.com",
    "role": "Student"
  }
}
```

### **Error Response**
```json
{
  "success": false,
  "errors": [
    "Email already exists",
    "Invalid email format"
  ],
  "user_id": null
}
```

### **Not Found Response**
```json
{
  "error": "User not found"
}
```

---

## ✅ Built-in Validations

### **Users**
- ✅ Email format validation
- ✅ Email uniqueness check
- ✅ Role validation (Admin, Coordinator, Supervisor, Student)
- ✅ Soft delete (sets status to Inactive)

### **OJT Records**
- ✅ Student role verification
- ✅ No overlapping records
- ✅ Date range validation
- ✅ Auto-completion when criteria met

### **Attendance**
- ✅ Active OJT record check
- ✅ Date within OJT period
- ✅ No duplicate entries
- ✅ Time logic validation (time_out > time_in)
- ✅ Future date prevention

### **Evaluations**
- ✅ Score range validation (0-100)
- ✅ Auto-prediction trigger on approval

---

## 🔄 Migration from Direct Queries

### **Before (Direct Query)**
```javascript
router.post('/users', async (req, res) => {
  const { full_name, email, password, role } = req.body;
  
  // Manual validation
  const existing = await query('SELECT * FROM users WHERE email = $1', [email]);
  if (existing.rows.length > 0) {
    return res.status(400).json({ error: 'Email exists' });
  }
  
  // Manual hash
  const hash = await bcrypt.hash(password, 10);
  
  // Insert
  const result = await query(
    'INSERT INTO users (full_name, email, password_hash, role) VALUES ($1, $2, $3, $4) RETURNING *',
    [full_name, email, hash, role]
  );
  
  res.json(result.rows[0]);
});
```

### **After (Stored Procedure)**
```javascript
router.post('/users', async (req, res) => {
  const { full_name, email, password, role } = req.body;
  const hash = await bcrypt.hash(password, 10);
  
  const result = await query(
    'SELECT create_user($1, $2, $3, $4, NULL, NULL, NULL) as result',
    [full_name, email, hash, role]
  );
  
  const response = result.rows[0].result;
  
  if (response.success) {
    res.status(201).json(response);
  } else {
    res.status(400).json(response);
  }
});
```

**Benefits:**
- ✅ Less code (50% reduction)
- ✅ Validation in database
- ✅ Consistent error handling
- ✅ Easier to maintain

---

## 🎯 Best Practices

### **1. Always Check `success` Field**
```javascript
const result = await query('SELECT create_user(...) as result', [...]);
const response = result.rows[0].result;

if (!response.success) {
  return res.status(400).json(response);
}
```

### **2. Handle Errors Gracefully**
```javascript
try {
  const result = await query('SELECT create_user(...) as result', [...]);
  // Handle result
} catch (error) {
  console.error('Database error:', error);
  res.status(500).json({ error: 'Internal server error' });
}
```

### **3. Use Transactions for Multiple Operations**
```javascript
await query('BEGIN');
try {
  await query('SELECT create_user(...)', [...]);
  await query('SELECT create_ojt_record(...)', [...]);
  await query('COMMIT');
} catch (error) {
  await query('ROLLBACK');
  throw error;
}
```

---

## 📝 Complete API Route Example

```javascript
const express = require('express');
const router = express.Router();
const { query } = require('../../config/db');
const bcrypt = require('bcryptjs');

// CREATE
router.post('/', async (req, res) => {
  try {
    const { full_name, email, password, role, student_id, course } = req.body;
    const password_hash = await bcrypt.hash(password, 10);
    
    const result = await query(
      'SELECT create_user($1, $2, $3, $4, $5, $6, NULL) as result',
      [full_name, email, password_hash, role, student_id, course]
    );
    
    const response = result.rows[0].result;
    
    if (response.success) {
      res.status(201).json(response);
    } else {
      res.status(400).json(response);
    }
  } catch (error) {
    console.error('Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// READ
router.get('/:id', async (req, res) => {
  try {
    const result = await query('SELECT get_user($1) as user', [req.params.id]);
    const user = result.rows[0].user;
    
    if (user.error) {
      return res.status(404).json(user);
    }
    
    res.json({ user });
  } catch (error) {
    console.error('Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// UPDATE
router.put('/:id', async (req, res) => {
  try {
    const { full_name, email, role, status, course } = req.body;
    
    const result = await query(
      'SELECT update_user($1, $2, $3, $4, $5, NULL, $6, NULL) as result',
      [req.params.id, full_name, email, role, status, course]
    );
    
    const response = result.rows[0].result;
    
    if (response.success) {
      res.json(response);
    } else {
      res.status(400).json(response);
    }
  } catch (error) {
    console.error('Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// DELETE
router.delete('/:id', async (req, res) => {
  try {
    const result = await query('SELECT delete_user($1) as result', [req.params.id]);
    const response = result.rows[0].result;
    
    if (response.success) {
      res.json(response);
    } else {
      res.status(404).json(response);
    }
  } catch (error) {
    console.error('Error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

module.exports = router;
```

---

## 🚀 Quick Reference

| Entity | Create | Read | Update | Delete |
|--------|--------|------|--------|--------|
| Users | `create_user(...)` | `get_user(id)` | `update_user(...)` | `delete_user(id)` |
| OJT Records | `create_ojt_record(...)` | `get_ojt_record(id)` | `update_ojt_record(...)` | `delete_ojt_record(id)` |
| Attendance | `create_attendance(...)` | `get_attendance(id)` | `update_attendance(...)` | `delete_attendance(id)` |
| Evaluations | `create_evaluation(...)` | `get_evaluation(id)` | `update_evaluation(...)` | `delete_evaluation(id)` |
| AI Insights | `create_ai_insight(...)` | `get_ai_insight(id)` | - | `delete_ai_insight(id)` |
| Reports | `create_system_report(...)` | `get_system_report(id)` | - | `delete_system_report(id)` |

---

## ✨ Summary

**Total CRUD Functions**: 22  
**Entities Covered**: 6  
**Built-in Validations**: Yes  
**Consistent Response Format**: Yes  
**Error Handling**: Comprehensive  

All CRUD operations are now available as stored procedures with validation, error handling, and consistent JSONB responses!

