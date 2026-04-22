import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static const String _prefsKey = 'api_custom_ip';
  static const int _apiPort = 3000;

  // Compile-time default — conditionally updated for web
  static const String _defaultBaseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:3000/api',
  );

  // Runtime-mutable URL (updated by saveIp / clearIp or web initialization)
  static String _baseUrl = _defaultBaseUrl;

  /// Current base URL (may be updated at runtime via [saveIp])
  static String get baseUrl => _baseUrl;

  /// Load saved IP from SharedPreferences and apply it to [baseUrl].
  /// Called once on app startup by NetworkDiscoveryService.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIp = prefs.getString(_prefsKey);
      if (savedIp != null && savedIp.isNotEmpty) {
        _baseUrl = 'http://$savedIp:$_apiPort/api';
      }
    } catch (_) {}
  }

  /// Persist [ip] and update the runtime [baseUrl].
  static Future<void> saveIp(String ip) async {
    _baseUrl = 'http://$ip:$_apiPort/api';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, ip);
    } catch (_) {}
  }

  /// Clear the saved custom IP and revert to the compile-time default.
  static Future<void> clearIp() async {
    _baseUrl = _defaultBaseUrl;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {}
  }

  /// Returns true if the user has previously saved a custom IP.
  static Future<bool> hasCustomIp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      return saved != null && saved.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // API Endpoints
  static const String auth = '/auth';
  static const String attendance = '/attendance';
  static const String evaluation = '/evaluation';
  static const String prediction = '/prediction';
  static const String reports = '/reports';
  static const String ojt = '/ojt';
  static const String ojtSites = '/ojt-sites';
  static const String studentReports = '/student-reports';
  static const String health = '/health';

  // Timeout durations
  static const Duration timeout = Duration(seconds: 30);
  static const Duration aiTimeout = Duration(seconds: 360); // 6 minutes to accommodate heavy AI tasks
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

