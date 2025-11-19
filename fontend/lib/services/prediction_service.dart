import '../models/ai_insight.dart';
import '../models/chatbot_log.dart';
import 'api_service.dart';
import '../core/config.dart';

class PredictionService {
  // Get AI insights
  static Future<List<AiInsight>> getInsights({int? studentId}) async {
    try {
      String endpoint = '${ApiConfig.prediction}/insights';
      if (studentId != null) {
        endpoint += '?student_id=$studentId';
      }

      final response = await ApiService.get(endpoint);
      final List<dynamic> data = response['insights'] ?? [];
      return data.map((json) => AiInsight.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch AI insights: $e');
    }
  }

  // Create AI insight
  static Future<AiInsight> createInsight({
    required int studentId,
    required String modelName,
    required String insightType,
    required Map<String, dynamic> result,
    double? confidence,
  }) async {
    try {
      final response = await ApiService.post(
        '${ApiConfig.prediction}/insights',
        {
          'student_id': studentId,
          'model_name': modelName,
          'insight_type': insightType,
          'result': result,
          if (confidence != null) 'confidence': confidence,
        },
      );

      return AiInsight.fromJson(response['insight']);
    } catch (e) {
      throw Exception('Failed to create AI insight: $e');
    }
  }

  // Get performance predictions
  static Future<List<Map<String, dynamic>>> getPerformancePredictions({
    int? studentId,
  }) async {
    try {
      String endpoint = '${ApiConfig.prediction}/performance';
      if (studentId != null) {
        endpoint += '?student_id=$studentId';
      }

      final response = await ApiService.get(endpoint);
      return List<Map<String, dynamic>>.from(response['performance'] ?? []);
    } catch (e) {
      throw Exception('Failed to fetch performance predictions: $e');
    }
  }

  // Get chatbot logs
  static Future<List<ChatbotLog>> getChatbotLogs({int? userId}) async {
    try {
      String endpoint = '${ApiConfig.prediction}/chatbot/logs';
      if (userId != null) {
        endpoint += '?user_id=$userId';
      }

      final response = await ApiService.get(endpoint);
      final List<dynamic> data = response['logs'] ?? [];
      return data.map((json) => ChatbotLog.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch chatbot logs: $e');
    }
  }

  // Save chatbot log
  static Future<ChatbotLog> saveChatbotLog({
    required int userId,
    required String query,
    required String response,
    required String modelUsed,
  }) async {
    try {
      final apiResponse = await ApiService.post(
        '${ApiConfig.prediction}/chatbot/logs',
        {
          'user_id': userId,
          'query': query,
          'response': response,
          'model_used': modelUsed,
        },
      );

      return ChatbotLog.fromJson(apiResponse['log']);
    } catch (e) {
      throw Exception('Failed to save chatbot log: $e');
    }
  }

  // Get daily risk prediction for a student
  static Future<Map<String, dynamic>> getDailyPrediction(int studentId) async {
    try {
      final response = await ApiService.get(
        '${ApiConfig.prediction}/daily/$studentId',
      );

      return Map<String, dynamic>.from(response);
    } catch (e) {
      throw Exception('Failed to load daily prediction: $e');
    }
  }
}

