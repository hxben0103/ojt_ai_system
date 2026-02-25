# Testing Geofencing, Fake GPS & Photo Evidence (Attendance Check-in)

Quick notes for validating geofence, anti-fake-GPS, verification status, and photo evidence.

## Prerequisites

1. **Backend**: Run migrations:
   - `database/migration_geofence_attendance.sql` (attendance optional columns + `ojt_sites`)
   - `database/migration_attendance_photos_verification.sql` (checkout_* , verification_status, photo paths)
2. **OJT Site**: Create at least one geofence site for the student’s company (e.g. via POST `/api/ojt-sites`), with `company_name` matching the student’s OJT record.
3. **Flutter config** (`lib/core/config.dart`):
   - `GeofenceConfig.enforceGeofence = true` → geofence check applied when site exists.
   - `GeofenceConfig.blockOutsideGeofence = true` → outside radius blocks check-in; `false` → only flagged.
   - `GeofenceConfig.blockIfMockLocation = false` (default) → mock is only flagged, not blocked.
   - `GeofenceConfig.requirePhotoForAttendance = true` → photo required; `allowNoPhotoFallback = false` → no fallback without photo.

## Test 1: Normal check-in (no Fake GPS)

- Ensure device location is **on** and **not** mock.
- Open Student Attendance and tap a segment (e.g. Morning In).
- Grant location and camera; complete check-in.
- **Expected**: Check-in succeeds. If a site exists and you’re inside, optional fields (e.g. `checkin_lat`, `inside_geofence`, `trust_score`) can be sent and stored.

## Test 2: Outside geofence (real location)

- Create an `ojt_sites` row with lat/lng/radius that does **not** include your current real location (e.g. another city).
- With **real** GPS (no Fake GPS), open Student Attendance and try check-in.
- **Expected**: With `enforceGeofence = true` and `blockOutsideGeofence = true`, a dialog “Outside work site” appears and check-in is **blocked**. With `blockOutsideGeofence = false`, check-in is allowed and record is **FLAGGED**.

## Test 3: Fake GPS app (mock location)

- Install a Fake GPS app (e.g. “Fake GPS” or “GPS Emulator”) and set a mock location.
- Enable “Allow mock locations” (or equivalent) in Android developer options if required.
- Open the app and try check-in.
- **Expected** (default flags):
  - With `blockIfMockLocation = false`: Check-in **succeeds**; backend may receive a lower `trust_score` and `trust_flags` (e.g. `mock_location`) if the app detects mock.
  - With `blockIfMockLocation = true`: Check-in can be **blocked** with a “Mock or simulated location is not allowed” dialog when mock is detected (Android only; iOS does not use mock detection).

## Test 4: Teleport / low accuracy (optional)

- **Teleport**: Hard to simulate without changing time/location quickly; the service compares last stored position and time to infer speed; >200 km/h implied speed adds `teleport_jump` and reduces score.
- **Low accuracy**: Use a location with very poor accuracy (e.g. indoor, or a mock app that reports high accuracy value); score can be reduced and `low_accuracy` added to flags.

## Test 5: Photo required

- With `requirePhotoForAttendance = true` and `allowNoPhotoFallback = false`, cancel or fail camera.
- **Expected**: Message “Photo is required for attendance. Please try again.” and check-in does not proceed. With `allowNoPhotoFallback = true`, check-in can proceed without photo (may be flagged).

## Test 6: Coordinator – FLAGGED filter and evidence

- As coordinator/supervisor, open **Verify Student Attendance** (or equivalent).
- Use the **Verification status** dropdown and select **FLAGGED**.
- **Expected**: Only attendance records with `verification_status = 'FLAGGED'` are shown.
- Open a record that has evidence: **Expected** “Evidence” section with verification_status, inside/outside geofence, trust score, lat/lng, trust flags, and photo thumbnail when stored.

## Quick DB checks

- After check-in, query `attendance` for the new row and confirm optional columns when sent:
  - `checkin_lat`, `checkin_lng`, `checkout_lat`, `checkout_lng`, `accuracy_m`, `distance_m`, `inside_geofence`, `trust_score`, `trust_flags`, `verification_status`, `checkin_photo_path`, `checkout_photo_path`.

## Turning off geofence enforcement

- Set `GeofenceConfig.enforceGeofence = false`: check-in is **not** blocked when outside the site; location/trust data can still be sent and stored for flagging only.
- Set `GeofenceConfig.blockOutsideGeofence = false`: when outside, check-in is allowed and record is **FLAGGED** for coordinator review.
