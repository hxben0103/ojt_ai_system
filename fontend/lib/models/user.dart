class User {
  final int? userId;
  final String fullName;
  final String email;
  final String? passwordHash;
  final String role;
  final String status;
  final DateTime? dateCreated;
  
  // Student-specific fields (nullable for non-students)
  final String? studentId;
  final String? course;
  final int? age;
  final String? gender;
  final String? contactNumber;
  final String? address;
  final String? profilePhoto;
  final int? requiredHours;

  User({
    this.userId,
    required this.fullName,
    required this.email,
    this.passwordHash,
    required this.role,
    this.status = 'Active',
    this.dateCreated,
    this.studentId,
    this.course,
    this.age,
    this.gender,
    this.contactNumber,
    this.address,
    this.profilePhoto,
    this.requiredHours,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'] as int?,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      passwordHash: json['password_hash'] as String?,
      role: json['role'] as String,
      status: json['status'] as String? ?? 'Active',
      dateCreated: json['date_created'] != null
          ? DateTime.parse(json['date_created'])
          : null,
      studentId: json['student_id'] as String?,
      course: json['course'] as String?,
      age: json['age'] as int?,
      gender: json['gender'] as String?,
      contactNumber: json['contact_number'] as String?,
      address: json['address'] as String?,
      profilePhoto: json['profile_photo'] as String?,
      requiredHours: json['required_hours'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (userId != null) 'user_id': userId,
      'full_name': fullName,
      'email': email,
      if (passwordHash != null) 'password_hash': passwordHash,
      'role': role,
      'status': status,
      if (dateCreated != null) 'date_created': dateCreated!.toIso8601String(),
      if (studentId != null) 'student_id': studentId,
      if (course != null) 'course': course,
      if (age != null) 'age': age,
      if (gender != null) 'gender': gender,
      if (contactNumber != null) 'contact_number': contactNumber,
      if (address != null) 'address': address,
      if (profilePhoto != null) 'profile_photo': profilePhoto,
      if (requiredHours != null) 'required_hours': requiredHours,
    };
  }

  User copyWith({
    int? userId,
    String? fullName,
    String? email,
    String? passwordHash,
    String? role,
    String? status,
    DateTime? dateCreated,
    String? studentId,
    String? course,
    int? age,
    String? gender,
    String? contactNumber,
    String? address,
    String? profilePhoto,
    int? requiredHours,
  }) {
    return User(
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role ?? this.role,
      status: status ?? this.status,
      dateCreated: dateCreated ?? this.dateCreated,
      studentId: studentId ?? this.studentId,
      course: course ?? this.course,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      contactNumber: contactNumber ?? this.contactNumber,
      address: address ?? this.address,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      requiredHours: requiredHours ?? this.requiredHours,
    );
  }
}

