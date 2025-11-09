import 'dart:convert';

class SystemReport {
  final int? reportId;
  final String reportType;
  final int generatedBy;
  final String? generatedByName;
  final Map<String, dynamic> content;
  final DateTime? createdAt;

  SystemReport({
    this.reportId,
    required this.reportType,
    required this.generatedBy,
    this.generatedByName,
    required this.content,
    this.createdAt,
  });

  factory SystemReport.fromJson(Map<String, dynamic> json) {
    return SystemReport(
      reportId: json['report_id'] as int?,
      reportType: json['report_type'] as String,
      generatedBy: json['generated_by'] as int,
      generatedByName: json['generated_by_name'] as String?,
      content: json['content'] is String
          ? Map<String, dynamic>.from(
              jsonDecode(json['content'] as String))
          : Map<String, dynamic>.from(json['content'] as Map),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (reportId != null) 'report_id': reportId,
      'report_type': reportType,
      'generated_by': generatedBy,
      'content': content,
    };
  }
}

