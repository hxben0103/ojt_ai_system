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

  // Create OJT record
  static Future<OjtRecord> createOjtRecord({
    required int studentId,
    String? companyName,
    required int coordinatorId,
    required int supervisorId,
    DateTime? startDate,
    DateTime? endDate,
    int? requiredHours,
    String? companyAddress,
    String? companyContact,
  }) async {
    try {
      final response = await ApiService.post(
        '${ApiConfig.ojt}/records',
        {
          'student_id': studentId,
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
}

