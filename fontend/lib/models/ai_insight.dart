import 'dart:convert';

class AiInsight {
  final int? insightId;
  final int studentId;
  final String? studentName;
  final String modelName;
  final String insightType;
  final Map<String, dynamic> result;
  final double? confidence;
  final DateTime? createdAt;
  final Map<String, dynamic>? inputData;

  AiInsight({
    this.insightId,
    required this.studentId,
    this.studentName,
    required this.modelName,
    required this.insightType,
    required this.result,
    this.confidence,
    this.createdAt,
    this.inputData,
  });

  factory AiInsight.fromJson(Map<String, dynamic> json) {
    return AiInsight(
      insightId: json['insight_id'] as int?,
      studentId: json['student_id'] as int,
      studentName: json['student_name'] as String?,
      modelName: json['model_name'] as String,
      insightType: json['insight_type'] as String,
      result: json['result'] is String
          ? Map<String, dynamic>.from(jsonDecode(json['result'] as String))
          : Map<String, dynamic>.from(json['result'] as Map),
      confidence: json['confidence'] != null
          ? double.parse(json['confidence'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      inputData: json['input_data'] != null
          ? (json['input_data'] is String
              ? Map<String, dynamic>.from(jsonDecode(json['input_data'] as String))
              : Map<String, dynamic>.from(json['input_data'] as Map))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (insightId != null) 'insight_id': insightId,
      'student_id': studentId,
      'model_name': modelName,
      'insight_type': insightType,
      'result': result,
      if (confidence != null) 'confidence': confidence,
      if (inputData != null) 'input_data': inputData,
    };
  }
}

