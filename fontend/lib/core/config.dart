// API Configuration
class ApiConfig {
  // Update this with your backend server URL based on your platform:
  // - Web development: 'http://localhost:3000/api'
  // - Android emulator: 'http://10.0.2.2:3000/api'
  // - iOS simulator: 'http://localhost:3000/api'
  // - Physical device: 'http://YOUR_IP_ADDRESS:3000/api' (e.g., 'http://192.168.1.100:3000/api')
  // - Production: 'https://your-domain.com/api'
  
  // TODO: Change this URL based on your deployment platform
  static const String baseUrl = 'http://localhost:3000/api';

  // API Endpoints
  static const String auth = '/auth';
  static const String attendance = '/attendance';
  static const String evaluation = '/evaluation';
  static const String prediction = '/prediction';
  static const String reports = '/reports';
  static const String ojt = '/ojt';
  static const String health = '/health';

  // Timeout duration
  static const Duration timeout = Duration(seconds: 30);
}

// App Constants
class AppConstants {
  static const String appName = 'OJT AI System';
  static const String appVersion = '1.0.0';
}
