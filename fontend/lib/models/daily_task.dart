import 'competency.dart';

class DailyTask {
  final int taskId;
  final int studentId;
  final DateTime date;
  final String taskDescription;
  final double hoursWorked;
  final int? supervisorId;
  final String status; // Pending, Approved, Rejected
  final String? remarks;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? coordinatorComment;
  final DateTime? coordinatorCommentAt;
  final List<Competency> competencies;

  DailyTask({
    required this.taskId,
    required this.studentId,
    required this.date,
    required this.taskDescription,
    required this.hoursWorked,
    this.supervisorId,
    required this.status,
    this.remarks,
    this.createdAt,
    this.updatedAt,
    this.coordinatorComment,
    this.coordinatorCommentAt,
    this.competencies = const [],
  });

  factory DailyTask.fromJson(Map<String, dynamic> json) {
    return DailyTask(
      taskId: json['taskId'] as int,
      studentId: json['studentId'] as int,
      date: DateTime.parse(json['date'] as String),
      taskDescription: json['taskDescription'] as String,
      hoursWorked: (json['hoursWorked'] as num?)?.toDouble() ?? 0.0,
      supervisorId: json['supervisorId'] as int?,
      status: json['status'] as String,
      remarks: json['remarks'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      coordinatorComment: json['coordinatorComment'] as String?,
      coordinatorCommentAt: json['coordinatorCommentAt'] != null 
          ? DateTime.parse(json['coordinatorCommentAt'] as String)
          : null,
      competencies: (json['competencies'] as List<dynamic>?)
              ?.map((c) => Competency.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'taskId': taskId,
      'studentId': studentId,
      'date': date.toIso8601String().split('T')[0],
      'taskDescription': taskDescription,
      'hoursWorked': hoursWorked,
      if (supervisorId != null) 'supervisorId': supervisorId,
      'status': status,
      if (remarks != null) 'remarks': remarks,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (coordinatorComment != null) 'coordinatorComment': coordinatorComment,
      if (coordinatorCommentAt != null) 'coordinatorCommentAt': coordinatorCommentAt!.toIso8601String(),
      'competencies': competencies.map((c) => c.toJson()).toList(),
    };
  }

  bool get isPending => status == 'Pending';
  bool get isApproved => status == 'Approved';
  bool get isRejected => status == 'Rejected';
}

class CompetencySummary {
  final int competencyId;
  final String title;
  final int pointValue;
  final double totalHours;
  final int taskCount;

  CompetencySummary({
    required this.competencyId,
    required this.title,
    required this.pointValue,
    required this.totalHours,
    required this.taskCount,
  });

  factory CompetencySummary.fromJson(Map<String, dynamic> json) {
    return CompetencySummary(
      competencyId: json['competencyId'] as int,
      title: json['title'] as String,
      pointValue: json['pointValue'] as int,
      totalHours: (json['totalHours'] as num?)?.toDouble() ?? 0.0,
      taskCount: json['taskCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'competencyId': competencyId,
      'title': title,
      'pointValue': pointValue,
      'totalHours': totalHours,
      'taskCount': taskCount,
    };
  }
}

