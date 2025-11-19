import '../models/attendance.dart';
import 'api_service.dart';
import '../core/config.dart';
import '../core/attendance_constants.dart';

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

  // Get today's attendance for a student
  static Future<Attendance?> getTodayAttendance(int studentId) async {
    try {
      final response = await ApiService.get(
        '${ApiConfig.attendance}/today/$studentId',
      );

      if (response['attendance'] == null) {
        return null;
      }

      return Attendance.fromJson(response['attendance']);
    } catch (e) {
      throw Exception('Failed to fetch today\'s attendance: $e');
    }
  }

  // Record time in (legacy support)
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

      // Handle validation errors from stored procedure
      if (response.containsKey('errors')) {
        throw Exception(response['errors']?.join(', ') ?? 'Validation failed');
      }

      return Attendance.fromJson(response['attendance']);
    } catch (e) {
      throw Exception('Failed to record time in: $e');
    }
  }

  // Record time out (legacy support)
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

      // Handle errors from stored procedure
      if (response.containsKey('error')) {
        throw Exception(response['error'] ?? 'Failed to record time out');
      }

      return Attendance.fromJson(response['attendance']);
    } catch (e) {
      throw Exception('Failed to record time out: $e');
    }
  }

  // Log time in with segment (new method)
  static Future<Attendance> logTimeIn({
    required int studentId,
    int? ojtRecordId,
    required String segment,
    String? date,
  }) async {
    try {
      final response = await ApiService.post(
        '${ApiConfig.attendance}/time-in',
        {
          'student_id': studentId,
          if (ojtRecordId != null) 'ojt_record_id': ojtRecordId,
          'segment': segment,
          if (date != null) 'date': date,
        },
      );

      // Handle validation errors
      if (response.containsKey('errors')) {
        throw Exception(response['errors']?.join(', ') ?? 'Validation failed');
      }
      if (response.containsKey('error')) {
        throw Exception(response['error'] ?? 'Failed to record time in');
      }

      return Attendance.fromJson(response['attendance']);
    } catch (e) {
      throw Exception('Failed to record time in: $e');
    }
  }

  // Log time out with segment (new method)
  static Future<Attendance> logTimeOut({
    required int studentId,
    required String segment,
    String? date,
    int? attendanceId,
  }) async {
    try {
      final response = await ApiService.put(
        '${ApiConfig.attendance}/time-out',
        {
          if (attendanceId != null) 'attendance_id': attendanceId,
          'student_id': studentId,
          'segment': segment,
          if (date != null) 'date': date,
        },
      );

      // Handle errors
      if (response.containsKey('errors')) {
        throw Exception(response['errors']?.join(', ') ?? 'Validation failed');
      }
      if (response.containsKey('error')) {
        throw Exception(response['error'] ?? 'Failed to record time out');
      }

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

  // Get attendance summary for a specific student (returns single summary object)
  static Future<Map<String, dynamic>> getAttendanceSummary(int studentId) async {
    try {
      final response = await ApiService.get(
        '${ApiConfig.attendance}/summary/$studentId',
      );

      return Map<String, dynamic>.from(response);
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

