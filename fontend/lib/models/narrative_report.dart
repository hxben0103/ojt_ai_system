class NarrativeReport {
  final int? reportId;
  final int studentId;
  final String? studentName;
  final String title;
  final String? description;
  final String filePath;
  final String? fileName;
  final String status;
  final String? feedback;
  final int? rating;
  final int? weekNumber;
  final DateTime? reportDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  NarrativeReport({
    this.reportId,
    required this.studentId,
    this.studentName,
    required this.title,
    this.description,
    required this.filePath,
    this.fileName,
    this.status = 'Pending',
    this.feedback,
    this.rating,
    this.weekNumber,
    this.reportDate,
    this.createdAt,
    this.updatedAt,
  });

  factory NarrativeReport.fromJson(Map<String, dynamic> json) {
    return NarrativeReport(
      reportId: json['report_id'],
      studentId: json['student_id'],
      studentName: json['student_name'],
      title: json['title'] ?? 'No Title',
      description: json['description'],
      filePath: json['file_path'] ?? '',
      fileName: json['file_name'],
      status: json['status'] ?? 'Pending',
      feedback: json['feedback'],
      rating: json['rating'],
      weekNumber: json['week_number'],
      reportDate: json['report_date'] != null 
          ? DateTime.parse(json['report_date']) 
          : null,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'report_id': reportId,
      'student_id': studentId,
      'title': title,
      'description': description,
      'file_path': filePath,
      'file_name': fileName,
      'status': status,
      'feedback': feedback,
      'rating': rating,
      'week_number': weekNumber,
      'report_date': reportDate?.toIso8601String(),
    };
  }
}
