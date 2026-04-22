import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

/// AI/Flask Server Configuration
/// 
/// This class provides configuration for the AI chatbot server (Flask).
class AiConfig {
  /// Base URL of the AI/Flask chatbot server
  static String chatbotBaseUrl = const String.fromEnvironment(
    'CHATBOT_URL',
    defaultValue: 'http://localhost:5000',
  );

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIp = prefs.getString('custom_server_ip');
    if (savedIp != null && savedIp.isNotEmpty) {
      setIp(savedIp);
    }
  }

  static void setIp(String ip) {
    chatbotBaseUrl = 'http://$ip:5000';
  }

  /// Full endpoint URL for the chat API (Now proxied through Node.js backend)
  static String get chatEndpoint => '${ApiConfig.baseUrl}/prediction/chat';
  
  /// Full endpoint URL for the greeting API
  static String get greetingEndpoint => '$chatbotBaseUrl/greeting';
}


