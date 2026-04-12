import '../models/competency.dart';
import '../models/daily_task.dart';
import 'api_service.dart';
import '../core/config.dart';

class DailyTaskService {
  // Get all competencies
  static Future<List<Competency>> getCompetencies({String? program}) async {
    try {
      final endpoint = program != null ? '/competencies?program=$program' : '/competencies';
      final response = await ApiService.get(endpoint);
      
      if (response.containsKey('error')) {
        throw Exception(response['error'].toString());
      }
      
      final List<dynamic> data = response['competencies'] as List<dynamic>? ?? [];
      return data.map((json) => Competency.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Failed to fetch competencies: $e');
    }
  }

  // Update competency point value (Admin only)
  static Future<Competency> updateCompetencyPointValue(int id, int newValue) async {
    try {
      final response = await ApiService.put(
        '/competencies/$id',
        {
          'pointValue': newValue,
        },
      );
      
      if (response.containsKey('error')) {
        throw Exception(response['error'].toString());
      }
      
      final data = response['competency'] ?? response;
      return Competency.fromJson(data as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to update competency: $e');
    }
  }

  // Get daily tasks for a student
  static Future<List<DailyTask>> getDailyTasksForStudent(int studentId) async {
    try {
      final response = await ApiService.get('/students/$studentId/daily-tasks');
      final List<dynamic> data = response['tasks'] as List<dynamic>? ?? [];
      return data.map((json) => DailyTask.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Failed to fetch daily tasks: $e');
    }
  }

  // Create a new daily task
  static Future<DailyTask> createDailyTask({
    required int studentId,
    required DateTime date,
    required String taskDescription,
    required double hoursWorked,
    required int competencyId,
  }) async {
    try {
      final response = await ApiService.post(
        '/students/$studentId/daily-tasks',
        {
          'date': date.toIso8601String().split('T')[0],
          'taskDescription': taskDescription,
          'hoursWorked': hoursWorked,
          'competencyId': competencyId,
        },
      );

      // Handle response structure - task might be nested
      final taskData = response['task'] ?? response;
      return DailyTask.fromJson(taskData as Map<String, dynamic>);
    } catch (e) {
      throw Exception('Failed to create daily task: $e');
    }
  }

  // Update task status (Approve/Reject) - Supervisor only
  static Future<DailyTask> updateTaskStatus({
    required int taskId,
    required String status, // 'Approved', 'Rejected', or 'Pending'
    String? remarks,
  }) async {
    try {
      final response = await ApiService.put(
        '/daily-tasks/$taskId/status',
        {
          'status': status,
          if (remarks != null) 'remarks': remarks,
        },
      );

      // Handle possible error responses (e.g. 400/404 coming back from ApiService)
      if (response.containsKey('error')) {
        final error = response['error'];
        if (error is Map) {
          throw Exception(error['message'] ?? 'Failed to update task status');
        } else if (error is String) {
          throw Exception(error);
        } else {
          throw Exception('Failed to update task status');
        }
      }

      // Some endpoints may return validation errors in an 'errors' array
      if (response.containsKey('errors')) {
        final errors = response['errors'];
        if (errors is List && errors.isNotEmpty) {
          throw Exception(errors.join(', '));
        }
        throw Exception('Failed to update task status');
      }

      final taskData = response['task'] ?? response;
      return DailyTask.fromJson(taskData as Map<String, dynamic>);
    } catch (e) {
      // Clean up nested "Exception: ..." prefixes for nicer UI messages
      String message = e.toString();
      if (message.startsWith('Exception: ')) {
        message = message.substring('Exception: '.length);
      }
      // If this was already a "Failed to update task status: X", keep only X
      const prefix = 'Failed to update task status: ';
      if (message.startsWith(prefix)) {
        message = message.substring(prefix.length);
      }
      throw Exception(message);
    }
  }

  // Get competency summary for a student (aggregated hours per competency)
  static Future<List<CompetencySummary>> getCompetencySummary(int studentId) async {
    try {
      final response = await ApiService.get('/students/$studentId/competency-summary');
      final List<dynamic> data = response['summary'] as List<dynamic>? ?? [];
      return data
          .map((json) => CompetencySummary.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch competency summary: $e');
    }
  }

  // Get pending tasks for a supervisor
  static Future<List<DailyTask>> getPendingTasksForSupervisor(int supervisorId) async {
    try {
      final response = await ApiService.get('/supervisors/$supervisorId/pending-tasks');
      final List<dynamic> data = response['tasks'] as List<dynamic>? ?? [];
      return data.map((json) => DailyTask.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Failed to fetch pending tasks: $e');
    }
  }
}

