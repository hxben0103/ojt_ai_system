import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../core/dio_client.dart';
import 'api_service.dart';

class ExportService {
  // Export attendance records as CSV
  static Future<void> exportAttendance({String? startDate, String? endDate}) async {
    try {
      String endpoint = '/exports/attendance';
      final params = <String>[];
      if (startDate != null) params.add('start=$startDate');
      if (endDate != null) params.add('end=$endDate');
      if (params.isNotEmpty) endpoint += '?${params.join('&')}';

      final response = await DioClient().dio.get(
        endpoint,
        options: Options(responseType: ResponseType.plain),
      );
      
      final csvData = response.data?.toString() ?? '';
      _downloadFile(csvData, 'attendance_export.csv');
    } catch (e) {
      throw Exception('Failed to export attendance: $e');
    }
  }

  // Export student list as CSV
  static Future<void> exportStudents() async {
    try {
      final response = await DioClient().dio.get(
        '/exports/students',
        options: Options(responseType: ResponseType.plain),
      );
      final csvData = response.data?.toString() ?? '';
      _downloadFile(csvData, 'students_export.csv');
    } catch (e) {
      throw Exception('Failed to export students: $e');
    }
  }

  // Export performance summary as CSV
  static Future<void> exportPerformance() async {
    try {
      final response = await DioClient().dio.get(
        '/exports/performance',
        options: Options(responseType: ResponseType.plain),
      );
      final csvData = response.data?.toString() ?? '';
      _downloadFile(csvData, 'performance_export.csv');
    } catch (e) {
      throw Exception('Failed to export performance: $e');
    }
  }

  // Cross-platform download helper
  static Future<void> _downloadFile(String content, String filename) async {
    print('ExportService: Attempting to provide $filename with ${content.length} characters of data.');
    
    if (kIsWeb) {
      final bytes = Uint8List.fromList(content.codeUnits);
      final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..style.display = 'none';
      
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      html.Url.revokeObjectUrl(url);
      print('ExportService: Web download triggered.');
    } else {
      try {
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/$filename');
        await file.writeAsString(content);
        
        print('ExportService: File saved to ${file.path}');
        
        // E4 FIX: Use share_plus to share CSV files instead of Printing.sharePdf
        // Printing.sharePdf expects PDF format and corrupts CSV data
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Exported data: $filename',
        );
      } catch (e) {
        print('ExportService: Mobile export failed: $e');
        rethrow;
      }
    }
  }
}
