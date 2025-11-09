import 'dart:convert';

class Evaluation {
  final int? evalId;
  final int studentId;
  final String? studentName;
  final int supervisorId;
  final String? supervisorName;
  final Map<String, dynamic> criteria;
  final double? totalScore;
  final String? feedback;
  final DateTime? dateEvaluated;

  Evaluation({
    this.evalId,
    required this.studentId,
    this.studentName,
    required this.supervisorId,
    this.supervisorName,
    required this.criteria,
    this.totalScore,
    this.feedback,
    this.dateEvaluated,
  });

  factory Evaluation.fromJson(Map<String, dynamic> json) {
    return Evaluation(
      evalId: json['eval_id'] as int?,
      studentId: json['student_id'] as int,
      studentName: json['student_name'] as String?,
      supervisorId: json['supervisor_id'] as int,
      supervisorName: json['supervisor_name'] as String?,
      criteria: json['criteria'] is String
          ? Map<String, dynamic>.from(
              jsonDecode(json['criteria'] as String))
          : Map<String, dynamic>.from(json['criteria'] as Map),
      totalScore: json['total_score'] != null
          ? double.parse(json['total_score'].toString())
          : null,
      feedback: json['feedback'] as String?,
      dateEvaluated: json['date_evaluated'] != null
          ? DateTime.parse(json['date_evaluated'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (evalId != null) 'eval_id': evalId,
      'student_id': studentId,
      'supervisor_id': supervisorId,
      'criteria': criteria,
      if (totalScore != null) 'total_score': totalScore,
      if (feedback != null) 'feedback': feedback,
    };
  }
}

