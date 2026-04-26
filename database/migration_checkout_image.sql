-- Migration: Add checkout_image column to attendance table
-- Purpose: Store time-out photo separately so time-in photo (attendance_image) is not overwritten
-- Date: 2026-04-26

-- Add checkout_image column (stores base64 text, same as attendance_image)
ALTER TABLE attendance ADD COLUMN IF NOT EXISTS checkout_image TEXT;

-- Add has_checkout_image computed helper for queries
COMMENT ON COLUMN attendance.checkout_image IS 'Base64-encoded photo captured during time-out. Stored separately from attendance_image (time-in photo) to preserve both as evidence.';
COMMENT ON COLUMN attendance.attendance_image IS 'Base64-encoded photo captured during time-in (checkin photo).';
