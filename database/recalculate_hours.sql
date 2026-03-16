-- Recalculate all attendance hours to populate total_hours and regular_hours
UPDATE attendance 
SET attendance_id = attendance_id -- dummy update to trigger calculation
WHERE 
    (morning_in IS NOT NULL AND morning_out IS NOT NULL) OR
    (afternoon_in IS NOT NULL AND afternoon_out IS NOT NULL) OR
    (overtime_in IS NOT NULL AND overtime_out IS NOT NULL);
