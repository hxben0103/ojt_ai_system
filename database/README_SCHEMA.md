# Database Schema Documentation

## Schema Files

### 1. `schema.sql` (Original)
- Basic schema with original table definitions
- Use this if you're starting fresh with minimal requirements

### 2. `schema_updates.sql` (Migration)
- Contains ALTER TABLE statements to add new fields
- Use this to update an existing database
- Maintains backward compatibility

### 3. `schema_full.sql` (Recommended - Complete)
- **Complete production-ready schema**
- Includes all tables, fields, indexes, views, and triggers
- Includes all enhancements for frontend requirements
- Use this for new installations

## Quick Start

### For New Installation (Recommended)
```bash
# Create database
psql -U postgres
CREATE DATABASE ojt_ai_system;
\q

# Run full schema
psql -U postgres -d ojt_ai_system -f database/schema_full.sql
```

### For Existing Database (Migration)
```bash
# Run updates only
psql -U postgres -d ojt_ai_system -f database/schema_updates.sql
```

## Schema Overview

### Tables

1. **users** - User accounts (Admin, Coordinator, Supervisor, Student)
   - Includes student-specific fields
   - Profile photos, contact information
   - Required hours for students

2. **ojt_records** - OJT placement records
   - Links students with coordinators and supervisors
   - Company information and contacts
   - Required and completed hours

3. **attendance** - Daily attendance records
   - Basic time in/out
   - Enhanced DTR with multiple time entries
   - Attendance images and signatures
   - Verification tracking

4. **evaluations** - Performance evaluations
   - Criteria stored as JSONB
   - Supervisor feedback
   - Evaluation periods

5. **ai_insights** - AI-generated insights
   - Performance predictions
   - Risk assessments
   - Model metadata

6. **chatbot_logs** - Chatbot conversations
   - Query and response tracking
   - Session management
   - User satisfaction ratings

7. **system_reports** - System-generated reports
   - Various report types
   - JSONB content storage
   - File path tracking

### Views

1. **view_active_students** - Active students with OJT details
2. **view_attendance_summary** - Attendance statistics per student
3. **view_ai_performance** - AI insights combined with evaluations
4. **view_coordinator_dashboard** - Coordinator overview
5. **view_reports_summary** - Report summaries
6. **view_student_progress** - Student progress tracking

### Triggers

1. **update_updated_at_column** - Automatically updates `updated_at` timestamp
2. **calculate_attendance_hours** - Automatically calculates total hours from time entries

### Indexes

- Optimized indexes on foreign keys
- Indexes on frequently queried fields
- GIN indexes on JSONB columns for efficient queries

## Key Features

### Enhanced DTR (Daily Time Record)
- Morning in/out
- Afternoon in/out
- Overtime in/out
- Automatic hour calculation
- Attendance images and signatures

### Student Profile
- Student ID
- Course/program
- Contact information
- Profile photos
- Required hours

### OJT Records
- Company details
- Contact information for all parties
- Required hours tracking
- Status management

### AI Integration
- Model version tracking
- Confidence scores
- Input/output data storage
- Processing time tracking

## Data Types

### JSONB Columns
- `evaluations.criteria` - Evaluation criteria and scores
- `ai_insights.result` - AI prediction results
- `ai_insights.input_data` - Input data for predictions
- `chatbot_logs.context` - Conversation context
- `system_reports.content` - Report data
- `system_reports.recipients` - Report recipients

### TEXT Columns (for file paths/URLs)
- `users.profile_photo` - Profile picture path/URL
- `attendance.attendance_image` - Attendance photo path/URL
- `attendance.signature` - Signature data/path
- `system_reports.file_path` - Generated report file path

## Security Considerations

1. **Password Hashing**: Always hash passwords using bcrypt (handled in backend)
2. **Foreign Keys**: Use ON DELETE CASCADE/RESTRICT appropriately
3. **Indexes**: Optimize queries without compromising write performance
4. **Views**: Use views for read-only access to aggregated data
5. **Triggers**: Automate calculations and timestamps

## Maintenance

### Regular Tasks
- Monitor index usage
- Review query performance
- Clean up old chatbot logs
- Archive old reports
- Update statistics: `ANALYZE;`

### Backup
```bash
# Backup database
pg_dump -U postgres ojt_ai_system > backup.sql

# Restore database
psql -U postgres ojt_ai_system < backup.sql
```

## Migration Notes

### From schema.sql to schema_full.sql
1. Run `schema_updates.sql` to add new fields
2. Views will be automatically updated
3. Triggers will be added
4. Existing data is preserved

### Backward Compatibility
- All new fields are nullable
- Existing queries continue to work
- Old fields remain functional
- New fields are optional

## Support

For issues or questions:
1. Check the schema comments in `schema_full.sql`
2. Review the views for data access patterns
3. Check trigger functions for automatic calculations
4. Verify indexes are being used: `EXPLAIN ANALYZE`

