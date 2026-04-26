import '../models/ojt_record.dart';
import '../models/narrative_report.dart';
import 'api_service.dart';
import '../core/config.dart';

/// Thrown when creating an OJT record for a student who already has an ongoing one.
/// The UI should catch this and offer to update the existing record instead.
class OjtExistsException implements Exception {
  final String message;
  final int? existingRecordId;
  final String? existingCompany;

  OjtExistsException(this.message, {this.existingRecordId, this.existingCompany});

  @override
  String toString() => message;
}

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

  /// Get aggregated supervisor overview (Optimized single-endpoint call)
  static Future<Map<String, dynamic>> getSupervisorOverview(int supervisorId) async {
    try {
      final response = await ApiService.get('${ApiConfig.ojt}/supervisor-overview/$supervisorId');
      if (response.containsKey('error')) {
        throw Exception(response['error'] is String 
            ? response['error'] 
            : response['error'].toString());
      }
      return Map<String, dynamic>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch supervisor overview: $e');
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

  // Create OJT record (or update existing if updateExisting=true)
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
    double? latitude,
    double? longitude,
    double? radiusMeters,
    bool updateExisting = false,
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
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
          if (radiusMeters != null) 'radius_meters': radiusMeters,
          if (updateExisting) 'update_existing': true,
        },
      );

      // Handle "student already has an existing record" (409 Conflict)
      if (response.containsKey('can_update') && response['can_update'] == true) {
        throw OjtExistsException(
          response['error']?.toString() ?? 'Student already has an active OJT record.',
          existingRecordId: response['existing_record_id'] as int?,
          existingCompany: response['existing_company']?.toString(),
        );
      }

      // Handle validation errors from stored procedure
      if (response.containsKey('errors')) {
        throw Exception(response['errors']?.join(', ') ?? 'Validation failed');
      }

      return OjtRecord.fromJson(response['record']);
    } on OjtExistsException {
      rethrow;
    } catch (e) {
      if (e is Exception) rethrow;
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

  // Upload narrative report
  static Future<Map<String, dynamic>> uploadNarrativeReport({
    required int studentId,
    required String title,
    required String description,
    required dynamic file, // File on mobile, Uint8List on web
    required String fileName,
    int? weekNumber,
  }) async {
    try {
      final response = await ApiService.uploadFile(
        ApiConfig.studentReports,
        file,
        fileName,
        fieldName: 'report_file',
        additionalData: {
          'student_id': studentId.toString(),
          'title': title,
          'description': description,
          if (weekNumber != null) 'week_number': weekNumber.toString(),
          'report_date': DateTime.now().toIso8601String().split('T')[0],
        },
      );

      if (response.containsKey('error')) {
        throw Exception(response['error'].toString());
      }

      return response;
    } catch (e) {
      throw Exception('Failed to upload narrative report: $e');
    }
  }

  // Get narrative reports for a student
  static Future<List<NarrativeReport>> getNarrativeReports({int? studentId}) async {
    try {
      final endpoint = studentId != null 
          ? '${ApiConfig.studentReports}/student/$studentId'
          : ApiConfig.studentReports;
          
      final response = await ApiService.get(endpoint);
      if (response.containsKey('error')) {
        throw Exception(response['error'].toString());
      }
      final List<dynamic> data = response['reports'] ?? [];
      return data.map((e) => NarrativeReport.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (e) {
      throw Exception('Failed to fetch narrative reports: $e');
    }
  }

  // Review narrative report (Coordinator only)
  static Future<NarrativeReport> reviewNarrativeReport({
    required int reportId,
    required String status,
    required int rating,
    String? feedback,
  }) async {
    try {
      final response = await ApiService.put(
        '${ApiConfig.studentReports}/$reportId/status',
        {
          'status': status,
          'rating': rating,
          if (feedback != null) 'feedback': feedback,
        },
      );

      if (response.containsKey('error')) {
        throw Exception(response['error'].toString());
      }

      final data = response['report'] ?? response;
      return NarrativeReport.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (e) {
      throw Exception('Failed to review narrative report: $e');
    }
  }

  // Get File URL for reports (accepts optional token for browser viewing)
  static String getNarrativeReportUrl(int reportId, {bool isDownload = false, String? token}) {
    final action = isDownload ? 'download' : 'view';
    String url = '${ApiConfig.baseUrl}${ApiConfig.studentReports}/$reportId/$action';
    if (token != null) {
      url += '?token=$token';
    }
    return url;
  }

  @Deprecated('Use uploadNarrativeReport instead')
  static Future<Map<String, dynamic>> uploadProgressReport({
    required int studentId,
    required String title,
    required String description,
    required dynamic file,
    required String fileName,
    int? weekNumber,
  }) => uploadNarrativeReport(
    studentId: studentId,
    title: title,
    description: description,
    file: file,
    fileName: fileName,
    weekNumber: weekNumber,
  );

  @Deprecated('Use getNarrativeReports instead')
  static Future<List<Map<String, dynamic>>> getStudentReports(int studentId) async {
    final reports = await getNarrativeReports(studentId: studentId);
    return reports.map((r) => r.toJson()).toList();
  }
}


