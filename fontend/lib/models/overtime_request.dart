class StudentName {
  final int userId;
  final String fullName;

  StudentName({required this.userId, required this.fullName});

  factory StudentName.fromJson(Map<String, dynamic> json) {
    return StudentName(
      userId: json['user_id'],
      fullName: json['full_name'] ?? 'Unknown',
    );
  }
}

class OvertimeRequest {
  final int requestId;
  final int supervisorId;
  final String? supervisorName;
  final int? coordinatorId;
  final String? coordinatorName;
  final DateTime date;
  final List<int> studentIds;
  final List<StudentName> studentNames;
  final String formalLetter;
  final String status; // 'Pending', 'Approved', 'Rejected'
  final String? coordinatorRemarks;
  final DateTime createdAt;

  OvertimeRequest({
    required this.requestId,
    required this.supervisorId,
    this.supervisorName,
    this.coordinatorId,
    this.coordinatorName,
    required this.date,
    required this.studentIds,
    this.studentNames = const [],
    required this.formalLetter,
    required this.status,
    this.coordinatorRemarks,
    required this.createdAt,
  });

  factory OvertimeRequest.fromJson(Map<String, dynamic> json) {
    final rawIds = json['student_ids'];
    List<int> ids = [];
    if (rawIds is List) {
      ids = rawIds.map<int>((e) => e is int ? e : int.parse(e.toString())).toList();
    }

    final rawNames = json['student_names'];
    List<StudentName> names = [];
    if (rawNames is List) {
      names = rawNames.map<StudentName>((e) => StudentName.fromJson(e)).toList();
    }

    return OvertimeRequest(
      requestId: json['request_id'],
      supervisorId: json['supervisor_id'],
      supervisorName: json['supervisor_name'],
      coordinatorId: json['coordinator_id'],
      coordinatorName: json['coordinator_name'],
      date: DateTime.parse(json['date']),
      studentIds: ids,
      studentNames: names,
      formalLetter: json['formal_letter'] ?? '',
      status: json['status'] ?? 'Pending',
      coordinatorRemarks: json['coordinator_remarks'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
