class Attendance {
  final int? attendanceId;
  final int studentId;
  final String? studentName;
  final DateTime date;
  final String? timeIn;
  final String? timeOut;
  final double? totalHours;
  final bool verified;
  
  // Enhanced DTR fields
  final String? attendanceImage;
  final String? signature;
  final String? morningIn;
  final String? morningOut;
  final String? afternoonIn;
  final String? afternoonOut;
  final String? overtimeIn;
  final String? overtimeOut;

  Attendance({
    this.attendanceId,
    required this.studentId,
    this.studentName,
    required this.date,
    this.timeIn,
    this.timeOut,
    this.totalHours,
    this.verified = false,
    this.attendanceImage,
    this.signature,
    this.morningIn,
    this.morningOut,
    this.afternoonIn,
    this.afternoonOut,
    this.overtimeIn,
    this.overtimeOut,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      attendanceId: json['attendance_id'] as int?,
      studentId: json['student_id'] as int,
      studentName: json['full_name'] as String?,
      date: DateTime.parse(json['date'] as String),
      timeIn: json['time_in'] as String?,
      timeOut: json['time_out'] as String?,
      totalHours: json['total_hours'] != null
          ? double.parse(json['total_hours'].toString())
          : null,
      verified: json['verified'] as bool? ?? false,
      attendanceImage: json['attendance_image'] as String?,
      signature: json['signature'] as String?,
      morningIn: json['morning_in'] as String?,
      morningOut: json['morning_out'] as String?,
      afternoonIn: json['afternoon_in'] as String?,
      afternoonOut: json['afternoon_out'] as String?,
      overtimeIn: json['overtime_in'] as String?,
      overtimeOut: json['overtime_out'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (attendanceId != null) 'attendance_id': attendanceId,
      'student_id': studentId,
      'date': date.toIso8601String().split('T')[0],
      if (timeIn != null) 'time_in': timeIn,
      if (timeOut != null) 'time_out': timeOut,
      if (totalHours != null) 'total_hours': totalHours,
      'verified': verified,
      if (attendanceImage != null) 'attendance_image': attendanceImage,
      if (signature != null) 'signature': signature,
      if (morningIn != null) 'morning_in': morningIn,
      if (morningOut != null) 'morning_out': morningOut,
      if (afternoonIn != null) 'afternoon_in': afternoonIn,
      if (afternoonOut != null) 'afternoon_out': afternoonOut,
      if (overtimeIn != null) 'overtime_in': overtimeIn,
      if (overtimeOut != null) 'overtime_out': overtimeOut,
    };
  }

  Attendance copyWith({
    int? attendanceId,
    int? studentId,
    String? studentName,
    DateTime? date,
    String? timeIn,
    String? timeOut,
    double? totalHours,
    bool? verified,
    String? attendanceImage,
    String? signature,
    String? morningIn,
    String? morningOut,
    String? afternoonIn,
    String? afternoonOut,
    String? overtimeIn,
    String? overtimeOut,
  }) {
    return Attendance(
      attendanceId: attendanceId ?? this.attendanceId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      date: date ?? this.date,
      timeIn: timeIn ?? this.timeIn,
      timeOut: timeOut ?? this.timeOut,
      totalHours: totalHours ?? this.totalHours,
      verified: verified ?? this.verified,
      attendanceImage: attendanceImage ?? this.attendanceImage,
      signature: signature ?? this.signature,
      morningIn: morningIn ?? this.morningIn,
      morningOut: morningOut ?? this.morningOut,
      afternoonIn: afternoonIn ?? this.afternoonIn,
      afternoonOut: afternoonOut ?? this.afternoonOut,
      overtimeIn: overtimeIn ?? this.overtimeIn,
      overtimeOut: overtimeOut ?? this.overtimeOut,
    );
  }
}

