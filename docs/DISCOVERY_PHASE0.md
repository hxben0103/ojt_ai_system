# Phase 0 — Discovery Summary (OJT AI System)

## 1) Flutter `/fontend/lib`

### Student time-in/time-out
- **Screen:** `dashboards/student_attendance_screen.dart` — `_handleAttendance(String label)` builds segment, gets GPS, geofence, trust, captures photo, then calls `AttendanceService.logTimeIn` or `logTimeOut`.
- **Service:** `services/attendance_service.dart` — `logTimeIn()` posts to `POST ${ApiConfig.attendance}/time-in`, `logTimeOut()` puts to `PUT ${ApiConfig.attendance}/time-out`. Optional fields already sent: `checkin_lat`, `checkin_lng`, `accuracy_m`, `distance_m`, `inside_geofence`, `trust_score`, `trust_flags`. Legacy `timeIn()` / `timeOut()` still present.

### API config and helpers
- **Config:** `core/config.dart` — `ApiConfig.baseUrl`, `ApiConfig.attendance`, `GeofenceConfig` (enforceGeofence, blockIfMockLocation, flagOnlyIfSuspicious).
- **HTTP:** `services/api_service.dart` — `ApiService.get/post/put` with JSON and Bearer token; base URL from `ApiConfig.baseUrl`.

### Existing models/services (geofence + trust)
- **Models:** `models/geofence_site.dart`, `models/location_evidence.dart`, `models/trust_result.dart`.
- **Services:** `services/location_service.dart`, `services/geofence_service.dart`, `services/location_security_service.dart`, `services/ojt_sites_service.dart`.

---

## 2) Node backend `/backend/api/routes`

- **Attendance:** `routes/attendance.js` — `POST /time-in`, `PUT /time-out`; uses `query()` from `../../config/db`; creates/updates via raw SQL and stored procedure `create_attendance()`. Optional geo/trust fields applied in a second `UPDATE attendance SET ...` block. `get_attendance(attendance_id)` used for response.
- **OJT sites:** `routes/ojtSites.js` — CRUD for `ojt_sites`; auth via `authenticateToken` (JWT).

---

## 3) Database `/database`

- **Attendance table:** `schema_full.sql` — `attendance` has `attendance_id`, `student_id`, `date`, `time_in`, `time_out`, `total_hours`, `morning_in`, `morning_out`, `afternoon_in`, `afternoon_out`, `overtime_in`, `overtime_out`, `attendance_image`, `signature`, `verified`, `verified_by`, `verified_at`, `status`, `created_at`, `updated_at`.
- **Geofence migration:** `migration_geofence_attendance.sql` — adds `checkin_lat`, `checkin_lng`, `accuracy_m`, `distance_m`, `inside_geofence`, `trust_score`, `trust_flags`; creates `ojt_sites` and trigger `update_ojt_sites_updated_at` using `update_updated_at_column()`.
- **Triggers:** `update_updated_at_column()` in `schema_full.sql`; triggers on `ojt_records`, `attendance`, `evaluations`, `ojt_daily_tasks`; migration uses `EXECUTE FUNCTION update_updated_at_column()`.
- **Stored procedures:** `stored_procedures_functions.sql` — `create_attendance(...)`, `get_attendance(p_attendance_id)` (returns JSONB with fixed column set; does not include new evidence columns).

---

## 4) Minimal edit targets

| Layer   | File(s) | Edits |
|--------|---------|--------|
| DB      | New migration | Add attendance columns (checkout_*, verification_status, *_photo_path, *_photo_captured_at); ensure trigger on ojt_sites. |
| Backend | `attendance.js` | Accept optional checkout_*, verification_status, photo paths/timestamps; verification_status logic; multer photo upload; GET filter by verification_status. |
| Backend | `api/index.js` | Serve static uploads if needed; multer already via route. |
| Flutter | `core/config.dart` | Add blockOutsideGeofence, requirePhotoForAttendance, allowNoPhotoFallback, trustScoreThreshold. |
| Flutter | `services/attendance_service.dart` | Add checkout* and photo path/captured_at params for time-out; optional multipart upload helper. |
| Flutter | `dashboards/student_attendance_screen.dart` | Use blockOutsideGeofence; send checkout lat/lng for time-out; require photo with allowNoPhotoFallback. |
| Flutter | `dashboards/student_dashboard.dart` | Replace risk label with Progress + AI explanation (top_reasons, recommendation). |
| Flutter | `dashboards/enhanced_student_dashboard.dart` | Same: Progress + AI explanation; remove RiskBadge. |
| Flutter | Coordinator screens | Attendance evidence (photos, lat/lng, trust, verification_status); filter FLAGGED. |
