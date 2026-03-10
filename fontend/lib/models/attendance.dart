class Attendance {
  final int? attendanceId;
  final int studentId;
  final String? studentName;
  final DateTime date;
  final String? timeIn;
  final String? timeOut;
  final double? totalHours;
  final bool verified;
  final int? verifiedBy;
  final DateTime? verifiedAt;
  final String? verifiedByName;
  
  // Enhanced DTR fields
  final String? attendanceImage;
  final String? signature;
  final String? morningIn;
  final String? morningOut;
  final String? afternoonIn;
  final String? afternoonOut;
  final String? overtimeIn;
  final String? overtimeOut;
  final String? status; // 'Pending', 'Approved', 'Rejected'

  // Evidence fields (geofence, trust, photo path) for coordinator/admin
  final String? verificationStatus; // AUTO_VERIFIED, FLAGGED, MANUAL_REVIEW
  final double? checkinLat;
  final double? checkinLng;
  final double? checkoutLat;
  final double? checkoutLng;
  final bool? insideGeofence;
  final int? trustScore;
  final String? trustFlags; // JSON array string
  final String? checkinPhotoPath;
  final String? checkoutPhotoPath;
  final bool? hasBase64Image;

  Attendance({
    this.attendanceId,
    required this.studentId,
    this.studentName,
    required this.date,
    this.timeIn,
    this.timeOut,
    this.totalHours,
    this.verified = false,
    this.verifiedBy,
    this.verifiedAt,
    this.verifiedByName,
    this.attendanceImage,
    this.signature,
    this.morningIn,
    this.morningOut,
    this.afternoonIn,
    this.afternoonOut,
    this.overtimeIn,
    this.overtimeOut,
    this.status,
    this.verificationStatus,
    this.checkinLat,
    this.checkinLng,
    this.checkoutLat,
    this.checkoutLng,
    this.insideGeofence,
    this.trustScore,
    this.trustFlags,
    this.checkinPhotoPath,
    this.checkoutPhotoPath,
    this.hasBase64Image,
  });

  factory Attendance.fromJson(Map<dynamic, dynamic> jsonRow) {
    final json = Map<String, dynamic>.from(jsonRow);
    return Attendance(
      attendanceId: json['attendance_id'] as int?,
      studentId: json['student_id'] as int,
      // Handle both 'student_name' (from stored procedure) and 'full_name' (from direct query)
      studentName: json['student_name'] as String? ?? json['full_name'] as String?,
      date: DateTime.parse(json['date'] as String),
      timeIn: json['time_in'] as String?,
      timeOut: json['time_out'] as String?,
      totalHours: json['total_hours'] != null
          ? double.parse(json['total_hours'].toString())
          : null,
      verified: json['verified'] as bool? ?? false,
      verifiedBy: json['verified_by'] as int?,
      verifiedAt: json['verified_at'] != null 
          ? DateTime.parse(json['verified_at'] as String)
          : null,
      verifiedByName: json['verified_by_name'] as String?,
      attendanceImage: json['attendance_image'] as String?,
      signature: json['signature'] as String?,
      morningIn: json['morning_in'] as String?,
      morningOut: json['morning_out'] as String?,
      afternoonIn: json['afternoon_in'] as String?,
      afternoonOut: json['afternoon_out'] as String?,
      overtimeIn: json['overtime_in'] as String?,
      overtimeOut: json['overtime_out'] as String?,
      status: json['status'] as String? ?? 'Pending',
      verificationStatus: json['verification_status'] as String?,
      checkinLat: _toDouble(json['checkin_lat']),
      checkinLng: _toDouble(json['checkin_lng']),
      checkoutLat: _toDouble(json['checkout_lat']),
      checkoutLng: _toDouble(json['checkout_lng']),
      insideGeofence: json['inside_geofence'] as bool?,
      trustScore: json['trust_score'] as int?,
      trustFlags: json['trust_flags'] as String?,
      checkinPhotoPath: json['checkin_photo_path'] as String?,
      checkoutPhotoPath: json['checkout_photo_path'] as String?,
      hasBase64Image: json['has_base64_image'] as bool?,
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
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
      if (verifiedBy != null) 'verified_by': verifiedBy,
      if (verifiedAt != null) 'verified_at': verifiedAt!.toIso8601String(),
      if (verifiedByName != null) 'verified_by_name': verifiedByName,
      if (attendanceImage != null) 'attendance_image': attendanceImage,
      if (signature != null) 'signature': signature,
      if (morningIn != null) 'morning_in': morningIn,
      if (morningOut != null) 'morning_out': morningOut,
      if (afternoonIn != null) 'afternoon_in': afternoonIn,
      if (afternoonOut != null) 'afternoon_out': afternoonOut,
      if (overtimeIn != null) 'overtime_in': overtimeIn,
      if (overtimeOut != null) 'overtime_out': overtimeOut,
      if (status != null) 'status': status,
      if (verificationStatus != null) 'verification_status': verificationStatus,
      if (checkinPhotoPath != null) 'checkin_photo_path': checkinPhotoPath,
      if (checkoutPhotoPath != null) 'checkout_photo_path': checkoutPhotoPath,
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
    int? verifiedBy,
    DateTime? verifiedAt,
    String? verifiedByName,
    String? attendanceImage,
    String? signature,
    String? morningIn,
    String? morningOut,
    String? afternoonIn,
    String? afternoonOut,
    String? overtimeIn,
    String? overtimeOut,
    String? status,
    String? verificationStatus,
    double? checkinLat,
    double? checkinLng,
    double? checkoutLat,
    double? checkoutLng,
    bool? insideGeofence,
    int? trustScore,
    String? trustFlags,
    String? checkinPhotoPath,
    String? checkoutPhotoPath,
    bool? hasBase64Image,
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
      verifiedBy: verifiedBy ?? this.verifiedBy,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      verifiedByName: verifiedByName ?? this.verifiedByName,
      attendanceImage: attendanceImage ?? this.attendanceImage,
      signature: signature ?? this.signature,
      morningIn: morningIn ?? this.morningIn,
      morningOut: morningOut ?? this.morningOut,
      afternoonIn: afternoonIn ?? this.afternoonIn,
      afternoonOut: afternoonOut ?? this.afternoonOut,
      overtimeIn: overtimeIn ?? this.overtimeIn,
      overtimeOut: overtimeOut ?? this.overtimeOut,
      status: status ?? this.status,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      checkinLat: checkinLat ?? this.checkinLat,
      checkinLng: checkinLng ?? this.checkinLng,
      checkoutLat: checkoutLat ?? this.checkoutLat,
      checkoutLng: checkoutLng ?? this.checkoutLng,
      insideGeofence: insideGeofence ?? this.insideGeofence,
      trustScore: trustScore ?? this.trustScore,
      trustFlags: trustFlags ?? this.trustFlags,
      checkinPhotoPath: checkinPhotoPath ?? this.checkinPhotoPath,
      checkoutPhotoPath: checkoutPhotoPath ?? this.checkoutPhotoPath,
      hasBase64Image: hasBase64Image ?? this.hasBase64Image,
    );
  }
}

