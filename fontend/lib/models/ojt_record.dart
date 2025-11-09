class OjtRecord {
  final int? recordId;
  final int studentId;
  final String? studentName;
  final String? companyName;
  final int coordinatorId;
  final String? coordinatorName;
  final int supervisorId;
  final String? supervisorName;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status;
  
  // Additional fields
  final int? requiredHours;
  final String? companyAddress;
  final String? companyContact;
  final String? supervisorContact;
  final String? coordinatorContact;

  OjtRecord({
    this.recordId,
    required this.studentId,
    this.studentName,
    this.companyName,
    required this.coordinatorId,
    this.coordinatorName,
    required this.supervisorId,
    this.supervisorName,
    this.startDate,
    this.endDate,
    this.status = 'Ongoing',
    this.requiredHours,
    this.companyAddress,
    this.companyContact,
    this.supervisorContact,
    this.coordinatorContact,
  });

  factory OjtRecord.fromJson(Map<String, dynamic> json) {
    return OjtRecord(
      recordId: json['record_id'] as int?,
      studentId: json['student_id'] as int,
      studentName: json['student_name'] as String?,
      companyName: json['company_name'] as String?,
      coordinatorId: json['coordinator_id'] as int,
      coordinatorName: json['coordinator_name'] as String?,
      supervisorId: json['supervisor_id'] as int,
      supervisorName: json['supervisor_name'] as String?,
      startDate: json['start_date'] != null
          ? DateTime.parse(json['start_date'])
          : null,
      endDate:
          json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      status: json['status'] as String? ?? 'Ongoing',
      requiredHours: json['required_hours'] as int?,
      companyAddress: json['company_address'] as String?,
      companyContact: json['company_contact'] as String?,
      supervisorContact: json['supervisor_contact'] as String?,
      coordinatorContact: json['coordinator_contact'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (recordId != null) 'record_id': recordId,
      'student_id': studentId,
      'company_name': companyName,
      'coordinator_id': coordinatorId,
      'supervisor_id': supervisorId,
      if (startDate != null)
        'start_date': startDate!.toIso8601String().split('T')[0],
      if (endDate != null) 'end_date': endDate!.toIso8601String().split('T')[0],
      'status': status,
      if (requiredHours != null) 'required_hours': requiredHours,
      if (companyAddress != null) 'company_address': companyAddress,
      if (companyContact != null) 'company_contact': companyContact,
      if (supervisorContact != null) 'supervisor_contact': supervisorContact,
      if (coordinatorContact != null) 'coordinator_contact': coordinatorContact,
    };
  }
}

