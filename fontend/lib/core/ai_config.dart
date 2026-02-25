/// AI/Flask Server Configuration
/// 
/// This class provides configuration for the AI chatbot server (Flask).
/// The chatbot URL can be overridden at build time using:
/// 
/// ```bash
/// flutter run --dart-define=CHATBOT_URL=http://10.0.0.56:5000
/// flutter build web --dart-define=CHATBOT_URL=https://api.myserver.com
/// ```
class AiConfig {
  /// Base URL of the AI/Flask chatbot server
  /// 
  /// Defaults to http://localhost:5000 for local development.
  /// Can be overridden via --dart-define=CHATBOT_URL=<url>
  /// 
  /// IMPORTANT: When switching networks/hotspots, update the IP address below!
  /// Find your IP: Windows: ipconfig | findstr IPv4
  /// Or use: flutter run --dart-define=CHATBOT_URL=http://YOUR_IP:5000
  static const String chatbotBaseUrl = String.fromEnvironment(
    'CHATBOT_URL',
    defaultValue: 'http://192.168.0.113:5000', // UPDATE THIS when IP changes!
  );

  /// Full endpoint URL for the chat API
  static String get chatEndpoint => '$chatbotBaseUrl/chat';
  
  /// Full endpoint URL for the greeting API
  static String get greetingEndpoint => '$chatbotBaseUrl/greeting';
}

