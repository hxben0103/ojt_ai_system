import '../models/evaluation.dart';
import 'api_service.dart';
import '../core/config.dart';

class EvaluationService {
  // Get all evaluations
  static Future<List<Evaluation>> getEvaluations({
    int? studentId,
    int? supervisorId,
  }) async {
    try {
      String endpoint = ApiConfig.evaluation;
      final params = <String>[];
      if (studentId != null) params.add('student_id=$studentId');
      if (supervisorId != null) params.add('supervisor_id=$supervisorId');
      if (params.isNotEmpty) endpoint += '?${params.join('&')}';

      final response = await ApiService.get(endpoint);
      final List<dynamic> data = response['evaluations'] ?? [];
      return data.map((json) => Evaluation.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch evaluations: $e');
    }
  }

  // Create evaluation
  static Future<Evaluation> createEvaluation({
    required int studentId,
    required int supervisorId,
    required Map<String, dynamic> criteria,
    double? totalScore,
    String? feedback,
    DateTime? evaluationPeriodStart,
    DateTime? evaluationPeriodEnd,
  }) async {
    try {
      final response = await ApiService.post(
        ApiConfig.evaluation,
        {
          'student_id': studentId,
          'supervisor_id': supervisorId,
          'criteria': criteria,
          if (totalScore != null) 'total_score': totalScore,
          if (feedback != null) 'feedback': feedback,
          if (evaluationPeriodStart != null)
            'evaluation_period_start': evaluationPeriodStart.toIso8601String().split('T')[0],
          if (evaluationPeriodEnd != null)
            'evaluation_period_end': evaluationPeriodEnd.toIso8601String().split('T')[0],
        },
      );

      // Handle validation errors from stored procedure
      if (response.containsKey('errors')) {
        throw Exception(response['errors']?.join(', ') ?? 'Validation failed');
      }

      return Evaluation.fromJson(response['evaluation']);
    } catch (e) {
      throw Exception('Failed to create evaluation: $e');
    }
  }

  // Update evaluation
  static Future<Evaluation> updateEvaluation({
    required int evalId,
    Map<String, dynamic>? criteria,
    double? totalScore,
    String? feedback,
    String? status,
  }) async {
    try {
      final response = await ApiService.put(
        '${ApiConfig.evaluation}/$evalId',
        {
          if (criteria != null) 'criteria': criteria,
          if (totalScore != null) 'total_score': totalScore,
          if (feedback != null) 'feedback': feedback,
          if (status != null) 'status': status,
        },
      );

      // Handle errors from stored procedure
      if (response.containsKey('errors')) {
        throw Exception(response['errors']?.join(', ') ?? 'Validation failed');
      }

      return Evaluation.fromJson(response['evaluation']);
    } catch (e) {
      throw Exception('Failed to update evaluation: $e');
    }
  }

  // Get evaluation by ID
  static Future<Evaluation> getEvaluation(int evalId) async {
    try {
      final response = await ApiService.get('${ApiConfig.evaluation}/$evalId');
      return Evaluation.fromJson(response['evaluation']);
    } catch (e) {
      throw Exception('Failed to fetch evaluation: $e');
    }
  }
}

