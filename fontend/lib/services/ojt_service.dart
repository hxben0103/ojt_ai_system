import '../models/ojt_record.dart';
import 'api_service.dart';
import '../core/config.dart';

class OjtService {
  // Get all OJT records
  static Future<List<OjtRecord>> getOjtRecords({
    int? studentId,
    int? coordinatorId,
    int? supervisorId,
    String? status,
  }) async {
    try {
      String endpoint = '${ApiConfig.ojt}/records';
      final params = <String>[];
      if (studentId != null) params.add('student_id=$studentId');
      if (coordinatorId != null) params.add('coordinator_id=$coordinatorId');
      if (supervisorId != null) params.add('supervisor_id=$supervisorId');
      if (status != null) params.add('status=$status');
      if (params.isNotEmpty) endpoint += '?${params.join('&')}';

      final response = await ApiService.get(endpoint);
      
      // Check for error in response
      if (response.containsKey('error')) {
        final error = response['error'];
        if (error is Map) {
          throw Exception(error['message'] ?? 'Failed to fetch OJT records');
        } else {
          throw Exception(error.toString());
        }
      }
      
      final List<dynamic> data = response['records'] ?? [];
      return data.map((json) => OjtRecord.fromJson(json)).toList();
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to fetch OJT records: $e');
    }
  }


  /// Look up students by alphanumeric school ID (e.g. "2021-00123").
  /// Returns a list of matching active students.
  static Future<List<Map<String, dynamic>>> lookupStudentBySchoolId(String schoolId) async {
    try {
      final response = await ApiService.get(
        '${ApiConfig.ojt}/lookup-student?school_id=${Uri.encodeComponent(schoolId.trim())}',
      );
      if (response.containsKey('error')) {
        throw Exception(response['error'].toString());
      }
      final List<dynamic> data = response['students'] ?? [];
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      throw Exception('Student lookup failed: $e');
    }
  }

  // Create OJT record
  static Future<OjtRecord> createOjtRecord({
    // Prefer schoolId (alphanumeric) — backend resolves to user_id automatically.
    // Provide studentId (integer) as fallback for backward compatibility.
    String? schoolId,
    int? studentId,
    String? companyName,
    required int coordinatorId,
    required int supervisorId,
    DateTime? startDate,
    DateTime? endDate,
    int? requiredHours,
    String? companyAddress,
    String? companyContact,
  }) async {
    assert(schoolId != null || studentId != null,
        'Either schoolId or studentId must be provided');
    try {
      final response = await ApiService.post(
        '${ApiConfig.ojt}/records',
        {
          if (schoolId != null) 'school_id': schoolId,
          if (studentId != null && schoolId == null) 'student_id': studentId,
          if (companyName != null) 'company_name': companyName,
          'coordinator_id': coordinatorId,
          'supervisor_id': supervisorId,
          if (startDate != null)
            'start_date': startDate.toIso8601String().split('T')[0],
          if (endDate != null)
            'end_date': endDate.toIso8601String().split('T')[0],
          if (requiredHours != null) 'required_hours': requiredHours,
          if (companyAddress != null) 'company_address': companyAddress,
          if (companyContact != null) 'company_contact': companyContact,
        },
      );

      // Handle validation errors from stored procedure
      if (response.containsKey('errors')) {
        throw Exception(response['errors']?.join(', ') ?? 'Validation failed');
      }

      return OjtRecord.fromJson(response['record']);
    } catch (e) {
      throw Exception('Failed to create OJT record: $e');
    }
  }

  // Get comprehensive student status
  static Future<Map<String, dynamic>> getStudentStatus(int studentId) async {
    try {
      final response = await ApiService.get(
        '${ApiConfig.ojt}/student-status/$studentId',
      );

      if (response.containsKey('error')) {
        throw Exception(response['error'] is String 
            ? response['error'] 
            : response['error'].toString());
      }

      return Map<String, dynamic>.from(response['status'] ?? {});
    } catch (e) {
      throw Exception('Failed to fetch student status: $e');
    }
  }
}

