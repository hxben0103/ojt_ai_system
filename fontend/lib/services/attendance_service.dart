import '../models/attendance.dart';
import 'api_service.dart';
import '../core/config.dart';
import '../core/attendance_constants.dart';
import 'ojt_service.dart';

class AttendanceService {
  // Get all attendance records (optional filter: verificationStatus = FLAGGED, etc.)
  // Upload an image to Supabase Storage via the backend
  static Future<Map<String, dynamic>> uploadImageToStorage({
    required int studentId,
    required String photoType,
    required List<int> imageBytes,
    String? fileName,
  }) async {
    try {
      final response = await ApiService.uploadFile(
        '${ApiConfig.attendance}/upload-photo',
        imageBytes,
        fileName ?? 'attendance_${studentId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        fieldName: 'photo',
        additionalData: {
          'student_id': studentId.toString(),
          'photo_type': photoType,
        },
      );
      return response;
    } catch (e) {
      throw Exception('Failed to upload photo: $e');
    }
  }

  static Future<List<Attendance>> getAttendance({
    int? studentId,
    String? date,
    String? verificationStatus,
  }) async {
    try {
      String endpoint = ApiConfig.attendance;
      final params = <String>[];
      if (studentId != null) params.add('student_id=$studentId');
      if (date != null) params.add('date=$date');
      if (verificationStatus != null && verificationStatus.isNotEmpty) {
        params.add('verification_status=${Uri.encodeComponent(verificationStatus)}');
      }
      if (params.isNotEmpty) endpoint += '?${params.join('&')}';

      final response = await ApiService.get(endpoint);
      final List<dynamic> data = response['attendance'] ?? [];
      return data.map((json) => Attendance.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch attendance: $e');
    }
  }

  // Get today's attendance for a student (allows passing a specific date)
  static Future<Attendance?> getTodayAttendance(int studentId, {String? date}) async {
    try {
      String endpoint = '${ApiConfig.attendance}/today/$studentId';
      if (date != null && date.isNotEmpty) {
        endpoint += '?date=$date';
      }

      final response = await ApiService.get(endpoint);

      if (response['attendance'] == null) {
        return null;
      }

      return Attendance.fromJson(response['attendance']);
    } catch (e) {
      throw Exception('Failed to fetch attendance: $e');
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

  // Log time in with segment (new method).
  // Optional geofence/trust/photo path fields: sent only when provided; backend stores if columns exist.
  static Future<Attendance> logTimeIn({
    required int studentId,
    int? ojtRecordId,
    required String segment,
    String? date,
    String? timeIn,  // Add explicit time_in parameter
    String? attendanceImage, // Base64 encoded image (legacy)
    // Optional location/trust fields (geofencing + anti-fake GPS)
    double? checkinLat,
    double? checkinLng,
    double? accuracyM,
    double? distanceM,
    bool? insideGeofence,
    int? trustScore,
    List<String>? trustFlags,
    String? checkinPhotoPath,
    String? photoUrl,
    String? checkinPhotoCapturedAt,
  }) async {
    try {
      final body = <String, dynamic>{
        'student_id': studentId,
        if (ojtRecordId != null) 'ojt_record_id': ojtRecordId,
        'segment': segment,
        if (date != null) 'date': date,
        if (timeIn != null) 'time_in': timeIn,
        if (attendanceImage != null) 'attendance_image': attendanceImage,
      };
      if (checkinLat != null) body['checkin_lat'] = checkinLat;
      if (checkinLng != null) body['checkin_lng'] = checkinLng;
      if (accuracyM != null) body['accuracy_m'] = accuracyM;
      if (distanceM != null) body['distance_m'] = distanceM;
      if (insideGeofence != null) body['inside_geofence'] = insideGeofence;
      if (trustScore != null) body['trust_score'] = trustScore;
      if (trustFlags != null && trustFlags.isNotEmpty) body['trust_flags'] = trustFlags;
      if (checkinPhotoPath != null) body['checkin_photo_path'] = checkinPhotoPath;
      if (photoUrl != null) body['photo_url'] = photoUrl;
      if (checkinPhotoCapturedAt != null) body['checkin_photo_captured_at'] = checkinPhotoCapturedAt;

      final response = await ApiService.post(
        '${ApiConfig.attendance}/time-in',
        body,
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

  // Log time out with segment (new method).
  // Optional geofence/trust/checkout/photo path fields: sent only when provided.
  static Future<Attendance> logTimeOut({
    required int studentId,
    required String segment,
    String? date,
    String? timeOut, // Add explicit time_out parameter
    int? attendanceId,
    String? attendanceImage, // Base64 encoded image (legacy)
    // Optional location/trust (checkout for time-out)
    double? checkinLat,
    double? checkinLng,
    double? checkoutLat,
    double? checkoutLng,
    double? accuracyM,
    double? distanceM,
    bool? insideGeofence,
    int? trustScore,
    List<String>? trustFlags,
    String? checkoutPhotoPath,
    String? checkoutPhotoUrl,
    String? checkoutPhotoCapturedAt,
  }) async {
    try {
      final body = <String, dynamic>{
        if (attendanceId != null) 'attendance_id': attendanceId,
        'student_id': studentId,
        'segment': segment,
        if (date != null) 'date': date,
        if (timeOut != null) 'time_out': timeOut,
        if (attendanceImage != null) 'attendance_image': attendanceImage,
      };
      if (checkinLat != null) body['checkin_lat'] = checkinLat;
      if (checkinLng != null) body['checkin_lng'] = checkinLng;
      if (checkoutLat != null) body['checkout_lat'] = checkoutLat;
      if (checkoutLng != null) body['checkout_lng'] = checkoutLng;
      if (accuracyM != null) body['accuracy_m'] = accuracyM;
      if (distanceM != null) body['distance_m'] = distanceM;
      if (insideGeofence != null) body['inside_geofence'] = insideGeofence;
      if (trustScore != null) body['trust_score'] = trustScore;
      if (trustFlags != null && trustFlags.isNotEmpty) body['trust_flags'] = trustFlags;
      if (checkoutPhotoPath != null) body['checkout_photo_path'] = checkoutPhotoPath;
      if (checkoutPhotoUrl != null) body['checkout_photo_url'] = checkoutPhotoUrl;
      if (checkoutPhotoCapturedAt != null) body['checkout_photo_captured_at'] = checkoutPhotoCapturedAt;

      final response = await ApiService.put(
        '${ApiConfig.attendance}/time-out',
        body,
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
      final List<dynamic> data = response['summary'] ?? [];
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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

  // Unverify attendance (remove verification)
  static Future<Attendance> unverifyAttendance(int attendanceId) async {
    try {
      final response = await ApiService.put(
        '${ApiConfig.attendance}/unverify/$attendanceId',
        {},
      );

      return Attendance.fromJson(response['attendance']);
    } catch (e) {
      throw Exception('Failed to unverify attendance: $e');
    }
  }

  // Get attendance records for a supervisor's students
  static Future<List<Attendance>> getAttendanceForSupervisor({
    required int supervisorId,
    String? date,
    int? studentId,
  }) async {
    try {
      // First get OJT records for this supervisor to find student IDs
      final ojtRecords = await OjtService.getOjtRecords(
        supervisorId: supervisorId,
      );

      if (ojtRecords.isEmpty) {
        return [];
      }

      final studentIds = ojtRecords.map((r) => r.studentId).toList();
      
      // Get attendance for these students
      String endpoint = ApiConfig.attendance;
      final params = <String>[];
      
      if (studentId != null && studentIds.contains(studentId)) {
        params.add('student_id=$studentId');
      } else {
        params.add('supervisor_id=$supervisorId');
      }
      
      if (date != null) {
        params.add('date=$date');
      }
      
      if (params.isNotEmpty) {
        endpoint += '?${params.join('&')}';
      }

      final response = await ApiService.get(endpoint);
      final List<dynamic> data = response['attendance'] ?? [];
      return data.map((json) => Attendance.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch attendance for supervisor: $e');
    }
  }

  // Get specific attendance image (lazy loading)
  static Future<String?> getAttendanceImage(int attendanceId) async {
    try {
      final response = await ApiService.get(
        '${ApiConfig.attendance}/$attendanceId/image',
      );
      return response['attendance_image'] as String?;
    } catch (e) {
      print('Error fetching attendance image: $e');
      return null;
    }
  }
}


