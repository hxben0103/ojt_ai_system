import '../models/attendance.dart';
import 'api_service.dart';
import '../core/config.dart';

class AttendanceService {
  // Get all attendance records
  static Future<List<Attendance>> getAttendance({
    int? studentId,
    String? date,
  }) async {
    try {
      String endpoint = ApiConfig.attendance;
      if (studentId != null || date != null) {
        final params = <String>[];
        if (studentId != null) params.add('student_id=$studentId');
        if (date != null) params.add('date=$date');
        endpoint += '?${params.join('&')}';
      }

      final response = await ApiService.get(endpoint);
      final List<dynamic> data = response['attendance'] ?? [];
      return data.map((json) => Attendance.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch attendance: $e');
    }
  }

  // Record time in
  static Future<Attendance> timeIn({
    required int studentId,
    String? date,
    String? timeIn,
  }) async {
    try {
      final response = await ApiService.post(
        '${ApiConfig.attendance}/time-in',
        {
          'student_id': studentId,
          if (date != null) 'date': date,
          if (timeIn != null) 'time_in': timeIn,
        },
      );

      return Attendance.fromJson(response['attendance']);
    } catch (e) {
      throw Exception('Failed to record time in: $e');
    }
  }

  // Record time out
  static Future<Attendance> timeOut({
    required int attendanceId,
    required String timeOut,
  }) async {
    try {
      final response = await ApiService.put(
        '${ApiConfig.attendance}/time-out',
        {
          'attendance_id': attendanceId,
          'time_out': timeOut,
        },
      );

      return Attendance.fromJson(response['attendance']);
    } catch (e) {
      throw Exception('Failed to record time out: $e');
    }
  }

  // Get attendance summary
  static Future<List<Map<String, dynamic>>> getSummary({
    int? studentId,
  }) async {
    try {
      String endpoint = '${ApiConfig.attendance}/summary';
      if (studentId != null) {
        endpoint += '?student_id=$studentId';
      }

      final response = await ApiService.get(endpoint);
      return List<Map<String, dynamic>>.from(response['summary'] ?? []);
    } catch (e) {
      throw Exception('Failed to fetch attendance summary: $e');
    }
  }

  // Verify attendance
  static Future<Attendance> verifyAttendance(int attendanceId) async {
    try {
      final response = await ApiService.put(
        '${ApiConfig.attendance}/verify/$attendanceId',
        {},
      );

      return Attendance.fromJson(response['attendance']);
    } catch (e) {
      throw Exception('Failed to verify attendance: $e');
    }
  }
}

