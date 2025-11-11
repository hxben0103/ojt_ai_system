import 'dart:convert';

class SystemReport {
  final int? reportId;
  final String reportType;
  final int generatedBy;
  final String? generatedByName;
  final Map<String, dynamic> content;
  final DateTime? createdAt;
  final String? status;
  final DateTime? reportPeriodStart;
  final DateTime? reportPeriodEnd;

  SystemReport({
    this.reportId,
    required this.reportType,
    required this.generatedBy,
    this.generatedByName,
    required this.content,
    this.createdAt,
    this.status,
    this.reportPeriodStart,
    this.reportPeriodEnd,
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
      status: json['status'] as String?,
      reportPeriodStart: json['report_period_start'] != null
          ? DateTime.parse(json['report_period_start'])
          : null,
      reportPeriodEnd: json['report_period_end'] != null
          ? DateTime.parse(json['report_period_end'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (reportId != null) 'report_id': reportId,
      'report_type': reportType,
      'generated_by': generatedBy,
      'content': content,
      if (status != null) 'status': status,
      if (reportPeriodStart != null)
        'report_period_start': reportPeriodStart!.toIso8601String().split('T')[0],
      if (reportPeriodEnd != null)
        'report_period_end': reportPeriodEnd!.toIso8601String().split('T')[0],
    };
  }
}

