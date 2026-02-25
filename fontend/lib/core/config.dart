// API Configuration
class ApiConfig {
  // Update this with your backend server URL based on your platform:
  // - Web development: 'http://localhost:3000/api'
  // - Android emulator: 'http://10.0.2.2:3000/api'
  // - iOS simulator: 'http://localhost:3000/api'
  // - Physical device: 'http://YOUR_IP_ADDRESS:3000/api' (e.g., 'http://192.168.1.100:3000/api')
  // - Production: 'https://your-domain.com/api'
  
  // IMPORTANT: When switching networks/hotspots, update the IP address below!
  // Find your IP: Windows: ipconfig | findstr IPv4
  // Or use environment variable: flutter run --dart-define=API_URL=http://YOUR_IP:3000/api
  
  // Supports environment variable for easy IP changes
  // Usage: flutter run --dart-define=API_URL=http://192.168.1.100:3000/api
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    // Default to localhost for development; override via --dart-define=API_URL for phones/other devices.
    defaultValue: 'http://localhost:3000/api',
  );

  // API Endpoints
  static const String auth = '/auth';
  static const String attendance = '/attendance';
  static const String evaluation = '/evaluation';
  static const String prediction = '/prediction';
  static const String reports = '/reports';
  static const String ojt = '/ojt';
  static const String ojtSites = '/ojt-sites';
  static const String health = '/health';

  // Timeout duration
  static const Duration timeout = Duration(seconds: 30);
}

/// Geofencing and location trust flags. All backward compatible when geofence not configured.
class GeofenceConfig {
  /// When true and a geofence site exists, check-in is blocked if outside radius.
  static const bool enforceGeofence = true;

  /// When true, block check-in when outside geofence; when false, allow but flag.
  static const bool blockOutsideGeofence = true;

  /// When true, block check-in if mock location is detected (Android). Default: flag only.
  static const bool blockIfMockLocation = false;

  /// When true, allow check-in but flag/store suspicious location; when false, treat suspicious as block (if blocking enabled).
  static const bool flagOnlyIfSuspicious = true;

  /// Require photo capture for every attendance (time-in and time-out).
  static const bool requirePhotoForAttendance = true;

  /// If camera fails, allow proceeding without photo only when this is true (attendance may be flagged).
  static const bool allowNoPhotoFallback = false;

  /// Trust score below this value triggers FLAGGED (backend default 60).
  static const int trustScoreThreshold = 60;
}

// App Constants
class AppConstants {
  static const String appName = 'OJT AI System';
  static const String appVersion = '1.0.0';
}
