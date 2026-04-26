import 'dart:convert';
import '../models/ai_insight.dart';
import '../models/chatbot_log.dart';
import 'api_service.dart';
import '../core/config.dart';
import 'cache_service.dart';

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
      final perfData = response['performance'];

      // Backend returns a single object, not an array — wrap it
      if (perfData == null) return [];
      if (perfData is List) {
        return perfData.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      // Single object response
      return [Map<String, dynamic>.from(perfData as Map)];
    } catch (e) {
      throw Exception('Failed to fetch performance predictions: $e');
    }
  }

  // Get chatbot logs
  // E2 FIX: Use canonical chatbot.js routes (previous prediction.js duplicates were removed)
  static Future<List<ChatbotLog>> getChatbotLogs({int? userId}) async {
    try {
      String endpoint = '/chatbot/history';
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
      // E2 FIX: Use canonical POST /api/chatbot/log (was deleted from prediction.js)
      final apiResponse = await ApiService.post(
        '/chatbot/log',
        {
          'user_id': userId,
          'query': query,
          'response': response,
          'model_used': modelUsed,
        },
      );

      // Check for error in response
      if (apiResponse.containsKey('error')) {
        throw Exception(apiResponse['error'] is String 
            ? apiResponse['error'] 
            : apiResponse['error'].toString());
      }

      if (!apiResponse.containsKey('log')) {
        throw Exception('Invalid response format: missing log data');
      }

      return ChatbotLog.fromJson(apiResponse['log']);
    } catch (e) {
      // Extract the actual error message without nested exceptions
      String errorMessage = 'Failed to save chatbot log';
      if (e is Exception) {
        final message = e.toString();
        // Remove "Exception: " prefix if present
        if (message.startsWith('Exception: ')) {
          errorMessage = message.substring(11);
        } else {
          errorMessage = message;
        }
      } else {
        errorMessage = e.toString();
      }
      throw Exception(errorMessage);
    }
  }

  // Stream daily prediction narrative
  static Stream<Map<String, dynamic>> getDailyPredictionStream(int studentId) async* {
    try {
      final stream = await ApiService.getStream('${ApiConfig.prediction}/daily/stream/$studentId');
      
      String buffer = "";
      await for (final chunk in stream) {
        final text = String.fromCharCodes(chunk);
        buffer += text;
        
        // We look for our --CHUNK-- delimiter used in server.py
        final parts = buffer.split("\n--CHUNK--\n");
        // Keep the last part in buffer if it doesn't end with delimiter
        buffer = parts.last;
        
        for (int i = 0; i < parts.length - 1; i++) {
          final part = parts[i].trim();
          if (part.isEmpty) continue;
          
          try {
            final json = Map<String, dynamic>.from(jsonDecode(part));
            yield json;
          } catch (e) {
            print('Stream parse error: $e for part: $part');
          }
        }
      }
    } catch (e) {
      yield {'type': 'error', 'message': e.toString()};
    }
  }

  // Get daily risk prediction for a student
  static Future<Map<String, dynamic>> getDailyPrediction(int studentId, {bool cacheOnly = false}) async {
    final cacheKey = 'daily_pred_$studentId';
    
    try {
      if (cacheOnly) {
        final cached = await CacheService.load(cacheKey, ignoreTtl: false);
        if (cached != null) return cached;
      }

      final response = await ApiService.get(
        '${ApiConfig.prediction}/daily/$studentId${cacheOnly ? "?cache_only=true" : ""}',
      );

      final result = Map<String, dynamic>.from(response);
      
      // Save successful AI responses to local cache (4 hour TTL matches backend throttling)
      if (result['ai_prediction'] != null) {
        await CacheService.save(cacheKey, result, ttl: const Duration(hours: 4));
      }
      
      return result;
    } catch (e) {
      // Fallback to cache on network failure
      final cached = await CacheService.load(cacheKey, ignoreTtl: true);
      if (cached != null) {
        cached['cached'] = true;
        cached['offline_fallback'] = true;
        return cached;
      }
      throw Exception('Failed to load daily prediction: $e');
    }
  }

  // Suggest competency based on task description
  static Future<String?> suggestCompetency(String description) async {
    try {
      final response = await ApiService.post(
        '${ApiConfig.prediction}/suggest-competency',
        {'description': description},
      );

      if (response['success'] == true) {
        return response['suggestion'] as String?;
      }
      return null;
    } catch (e) {
      print('Competency suggestion error: $e');
      return null;
    }
  }
}


