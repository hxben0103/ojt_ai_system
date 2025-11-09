// Example usage of the API services
// This file demonstrates how to use the services in your Flutter app

import '../services/auth_service.dart';
import '../services/attendance_service.dart';
import '../services/evaluation_service.dart';
import '../services/ojt_service.dart';
import '../services/prediction_service.dart';
import '../services/report_service.dart';
import '../models/user.dart';
import '../models/attendance.dart';

class ExampleUsage {
  // Example: Register a new user
  static Future<void> registerUser() async {
    try {
      final response = await AuthService.register(
        fullName: 'John Doe',
        email: 'john@example.com',
        password: 'password123',
        role: 'Student',
      );
      print('User registered: ${response['user']}');
      print('Token: ${response['token']}');
    } catch (e) {
      print('Registration error: $e');
    }
  }

  // Example: Login
  static Future<void> loginUser() async {
    try {
      final response = await AuthService.login(
        email: 'john@example.com',
        password: 'password123',
      );
      print('Login successful: ${response['user']}');
    } catch (e) {
      print('Login error: $e');
    }
  }

  // Example: Get current user
  static Future<void> getCurrentUser() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user != null) {
        print('Current user: ${user.fullName} (${user.role})');
      } else {
        print('No user logged in');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  // Example: Record time in
  static Future<void> recordTimeIn(int studentId) async {
    try {
      final attendance = await AttendanceService.timeIn(
        studentId: studentId,
      );
      print('Time in recorded: ${attendance.attendanceId}');
    } catch (e) {
      print('Error: $e');
    }
  }

  // Example: Record time out
  static Future<void> recordTimeOut(int attendanceId) async {
    try {
      final now = DateTime.now();
      final timeOut = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      
      final attendance = await AttendanceService.timeOut(
        attendanceId: attendanceId,
        timeOut: timeOut,
      );
      print('Time out recorded: ${attendance.totalHours} hours');
    } catch (e) {
      print('Error: $e');
    }
  }

  // Example: Get attendance records
  static Future<void> getAttendanceRecords(int? studentId) async {
    try {
      final attendance = await AttendanceService.getAttendance(
        studentId: studentId,
      );
      print('Found ${attendance.length} attendance records');
      for (var record in attendance) {
        print('${record.date}: ${record.timeIn} - ${record.timeOut} (${record.totalHours} hours)');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  // Example: Create evaluation
  static Future<void> createEvaluation({
    required int studentId,
    required int supervisorId,
  }) async {
    try {
      final evaluation = await EvaluationService.createEvaluation(
        studentId: studentId,
        supervisorId: supervisorId,
        criteria: {
          'punctuality': 90,
          'quality': 85,
          'teamwork': 95,
          'communication': 88,
        },
        totalScore: 89.5,
        feedback: 'Excellent performance overall. Keep up the good work!',
      );
      print('Evaluation created: ${evaluation.evalId}');
    } catch (e) {
      print('Error: $e');
    }
  }

  // Example: Get OJT records
  static Future<void> getOjtRecords({int? studentId}) async {
    try {
      final records = await OjtService.getOjtRecords(
        studentId: studentId,
      );
      print('Found ${records.length} OJT records');
      for (var record in records) {
        print('${record.studentName} - ${record.companyName} (${record.status})');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  // Example: Get AI insights
  static Future<void> getAiInsights({int? studentId}) async {
    try {
      final insights = await PredictionService.getInsights(
        studentId: studentId,
      );
      print('Found ${insights.length} AI insights');
      for (var insight in insights) {
        print('${insight.insightType}: ${insight.result} (confidence: ${insight.confidence})');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  // Example: Save chatbot log
  static Future<void> saveChatbotLog({
    required int userId,
    required String query,
    required String response,
  }) async {
    try {
      final log = await PredictionService.saveChatbotLog(
        userId: userId,
        query: query,
        response: response,
        modelUsed: 'ollama-llama3',
      );
      print('Chatbot log saved: ${log.chatId}');
    } catch (e) {
      print('Error: $e');
    }
  }

  // Example: Create report
  static Future<void> createReport({
    required int userId,
    required String reportType,
  }) async {
    try {
      final report = await ReportService.createReport(
        reportType: reportType,
        generatedBy: userId,
        content: {
          'title': 'Monthly Attendance Report',
          'period': '2024-01',
          'summary': {
            'total_students': 50,
            'total_hours': 1200,
            'average_hours': 24,
          },
        },
      );
      print('Report created: ${report.reportId}');
    } catch (e) {
      print('Error: $e');
    }
  }

  // Example: Logout
  static Future<void> logout() async {
    try {
      await AuthService.logout();
      print('User logged out successfully');
    } catch (e) {
      print('Error: $e');
    }
  }
}

