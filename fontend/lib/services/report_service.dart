import '../models/system_report.dart';
import 'api_service.dart';
import '../core/config.dart';

class ReportService {
  // Get all reports
  static Future<List<SystemReport>> getReports({
    String? reportType,
    int? generatedBy,
  }) async {
    try {
      String endpoint = ApiConfig.reports;
      final params = <String>[];
      if (reportType != null) params.add('report_type=$reportType');
      if (generatedBy != null) params.add('generated_by=$generatedBy');
      if (params.isNotEmpty) endpoint += '?${params.join('&')}';

      final response = await ApiService.get(endpoint);
      final List<dynamic> data = response['reports'] ?? [];
      return data.map((json) => SystemReport.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch reports: $e');
    }
  }

  // Create report
  static Future<SystemReport> createReport({
    required String reportType,
    required int generatedBy,
    required Map<String, dynamic> content,
  }) async {
    try {
      final response = await ApiService.post(
        ApiConfig.reports,
        {
          'report_type': reportType,
          'generated_by': generatedBy,
          'content': content,
        },
      );

      return SystemReport.fromJson(response['report']);
    } catch (e) {
      throw Exception('Failed to create report: $e');
    }
  }

  // Get report by ID
  static Future<SystemReport> getReport(int reportId) async {
    try {
      final response = await ApiService.get('${ApiConfig.reports}/$reportId');
      return SystemReport.fromJson(response['report']);
    } catch (e) {
      throw Exception('Failed to fetch report: $e');
    }
  }
}

