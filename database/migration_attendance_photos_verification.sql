-- Migration: Attendance photo paths, checkout coordinates, verification status.
-- Run after schema_full.sql and migration_geofence_attendance.sql. Safe to run multiple times.

-- ========== Optional columns on attendance (checkout + verification + photo paths) ==========
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'attendance' AND column_name = 'checkout_lat') THEN
    ALTER TABLE attendance ADD COLUMN checkout_lat DOUBLE PRECISION;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'attendance' AND column_name = 'checkout_lng') THEN
    ALTER TABLE attendance ADD COLUMN checkout_lng DOUBLE PRECISION;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'attendance' AND column_name = 'verification_status') THEN
    ALTER TABLE attendance ADD COLUMN verification_status VARCHAR(30) DEFAULT 'AUTO_VERIFIED';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'attendance' AND column_name = 'checkin_photo_path') THEN
    ALTER TABLE attendance ADD COLUMN checkin_photo_path TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'attendance' AND column_name = 'checkout_photo_path') THEN
    ALTER TABLE attendance ADD COLUMN checkout_photo_path TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'attendance' AND column_name = 'checkin_photo_captured_at') THEN
    ALTER TABLE attendance ADD COLUMN checkin_photo_captured_at TIMESTAMP;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'attendance' AND column_name = 'checkout_photo_captured_at') THEN
    ALTER TABLE attendance ADD COLUMN checkout_photo_captured_at TIMESTAMP;
  END IF;
END $$;

-- Ensure default for existing rows (optional)
UPDATE attendance SET verification_status = 'AUTO_VERIFIED' WHERE verification_status IS NULL;
