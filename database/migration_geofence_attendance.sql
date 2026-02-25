-- Migration: Geofencing + location trust fields for attendance, and ojt_sites table.
-- Run this after schema_full.sql. Safe to run multiple times (IF NOT EXISTS / ADD COLUMN IF NOT EXISTS where supported).

-- ========== Optional columns on attendance (geofence + trust) ==========
-- PostgreSQL 9.5+ does not have "ADD COLUMN IF NOT EXISTS"; use DO block to avoid errors if column exists.

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'attendance' AND column_name = 'checkin_lat') THEN
    ALTER TABLE attendance ADD COLUMN checkin_lat DOUBLE PRECISION;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'attendance' AND column_name = 'checkin_lng') THEN
    ALTER TABLE attendance ADD COLUMN checkin_lng DOUBLE PRECISION;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'attendance' AND column_name = 'accuracy_m') THEN
    ALTER TABLE attendance ADD COLUMN accuracy_m DOUBLE PRECISION;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'attendance' AND column_name = 'distance_m') THEN
    ALTER TABLE attendance ADD COLUMN distance_m DOUBLE PRECISION;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'attendance' AND column_name = 'inside_geofence') THEN
    ALTER TABLE attendance ADD COLUMN inside_geofence BOOLEAN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'attendance' AND column_name = 'trust_score') THEN
    ALTER TABLE attendance ADD COLUMN trust_score INTEGER;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'attendance' AND column_name = 'trust_flags') THEN
    ALTER TABLE attendance ADD COLUMN trust_flags TEXT;
  END IF;
END $$;

-- ========== ojt_sites table (only if not exists) ==========
CREATE TABLE IF NOT EXISTS ojt_sites (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  radius_meters DOUBLE PRECISION DEFAULT 100,
  company_id INTEGER,
  company_name VARCHAR(255),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Trigger for updated_at on ojt_sites (reuse existing function from schema)
DROP TRIGGER IF EXISTS update_ojt_sites_updated_at ON ojt_sites;
CREATE TRIGGER update_ojt_sites_updated_at
  BEFORE UPDATE ON ojt_sites
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Optional index for filtering by company
CREATE INDEX IF NOT EXISTS idx_ojt_sites_company_name ON ojt_sites(company_name);
CREATE INDEX IF NOT EXISTS idx_ojt_sites_company_id ON ojt_sites(company_id);
