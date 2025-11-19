import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/role_dashboard.dart';
import '../widgets/role_guard.dart';
import 'student_checklist_screen.dart';
import 'student_attendance_screen.dart';
import 'student_dtr_view_screen.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import '../services/attendance_service.dart';
import '../screens/student/student_progress_report_screen.dart';
import '../services/auth_service.dart';
import '../services/ojt_service.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard>
    with SingleTickerProviderStateMixin {
  File? _attendanceImage;
  File? _profileImage;
  Uint8List? _profileImageBytes;
  bool _isTimedIn = false;
  String? _lastActionTime;
  int _completedHours = 0;
  int _requiredHours = 300;
  final picker = ImagePicker();

  int? _studentUserId;
  String? _studentName;
  String? _studentId;
  String? _course;
  String? _coordinator;
  String? _supervisor;

  List<Map<String, dynamic>> _dtrRecords = [];

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  bool _isLoading = false; // ✅ Added loading flag

  @override
  void initState() {
    super.initState();
    _initDashboardData();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initDashboardData() async {
    await _loadStudentData();
    await _loadAttendanceData();
    await _loadDTRRecords();
  }

  // ------------------- Loaders -------------------
  Future<void> _loadStudentData() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user != null) {
        final imageBytes = _decodeProfilePhoto(user.profilePhoto);
        setState(() {
          _studentUserId = user.userId;
          _studentName = user.fullName;
          _studentId =
              user.studentId ?? (user.userId != null ? '${user.userId}' : 'N/A');
          _course = user.course ?? 'N/A';
          _requiredHours = user.requiredHours ?? _requiredHours;
          _profileImageBytes = imageBytes;
          _profileImage = null;
        });

        if (user.userId != null) {
          try {
            final records =
                await OjtService.getOjtRecords(studentId: user.userId);
            if (records.isNotEmpty) {
              final record = records.first;
              setState(() {
                _coordinator = record.coordinatorName ?? _coordinator;
                _supervisor = record.supervisorName ?? _supervisor;
                if (record.requiredHours != null) {
                  _requiredHours = record.requiredHours!;
                }
              });
            }
          } catch (_) {
            // ignore OJT fetch errors
          }
        }
        return;
      }
    } catch (_) {
      // ignore errors and use local data instead
    }

    await _loadStudentDataFromPrefs();
  }

  Future<void> _loadStudentDataFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _studentUserId ??= prefs.getInt('student_user_id');
      _studentName = prefs.getString('student_name') ?? "Unknown";
      _studentId = prefs.getString('student_id') ?? "N/A";
      _course = prefs.getString('student_course') ?? "N/A";
      _coordinator = prefs.getString('student_coordinator') ?? "Pending";
      _supervisor = prefs.getString('student_supervisor') ?? "Pending";
      _requiredHours = prefs.getInt('student_required_hours') ?? _requiredHours;

      final profilePath = prefs.getString('student_photo');
      if (profilePath != null && File(profilePath).existsSync()) {
        _profileImage = File(profilePath);
        _profileImageBytes = null;
      } else {
        _profileImage = null;
        _profileImageBytes = null;
      }
    });
  }

  Future<void> _loadAttendanceData() async {
    int calculatedHours = _completedHours;
    if (_studentUserId != null) {
      try {
        final summary =
            await AttendanceService.getAttendanceSummary(_studentUserId!);
        final totalHours = summary['total_hours_completed'];
        if (totalHours is num) {
          calculatedHours = totalHours.round();
        }
      } catch (_) {
        // ignore summary errors
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('attendance_image');
    final isTimedIn = prefs.getBool('is_timed_in') ?? false;
    final lastTime = prefs.getString('last_action_time');
    final localHours = prefs.getInt('completed_hours');

    setState(() {
      _isTimedIn = isTimedIn;
      _lastActionTime = lastTime;
      _completedHours = localHours ?? calculatedHours;
      if (imagePath != null && File(imagePath).existsSync()) {
        _attendanceImage = File(imagePath);
      }
    });
  }

  Future<void> _loadDTRRecords() async {
    try {
      int? studentId = _studentUserId;
      if (studentId == null) {
        final prefs = await SharedPreferences.getInstance();
        final studentIdStr = prefs.getString('student_id');
        if (studentIdStr != null) {
          studentId = int.tryParse(studentIdStr);
        }
      }

      if (studentId != null) {
        final attendanceList = await AttendanceService.getAttendance(
          studentId: studentId,
        );

        final List<Map<String, dynamic>> dtrList = attendanceList
            .map((attendance) => {
                  'date': attendance.date.toIso8601String().split('T')[0],
                  'amIn': attendance.morningIn ?? '-',
                  'amOut': attendance.morningOut ?? '-',
                  'pmIn': attendance.afternoonIn ?? '-',
                  'pmOut': attendance.afternoonOut ?? '-',
                  'otIn': attendance.overtimeIn ?? '-',
                  'otOut': attendance.overtimeOut ?? '-',
                  'totalHours': attendance.totalHours?.toStringAsFixed(1) ?? '0',
                })
            .toList();

        setState(() {
          _dtrRecords = dtrList;
        });
        return;
      }

      // If no student ID, set empty list
      setState(() {
        _dtrRecords = [];
      });
    } catch (e) {
      // On error, set empty list
      setState(() {
        _dtrRecords = [];
      });
    }
  }

  // ------------------- UI -------------------
  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allowedRoles: const ['student'],
      builder: (ctx, user) => _buildDashboardContent(ctx),
    );
  }

  Widget _buildDashboardContent(BuildContext context) {
    // ✅ Show loading animation if logging out
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/logo.gif', height: 180)
                  .animate()
                  .fadeIn(duration: 900.ms)
                  .scale(duration: 900.ms),
              const SizedBox(height: 25),
            ],
          ),
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: RoleDashboard(
        title: "Student Dashboard",
        color: Colors.orange,
        tasks: const [],
        customActions: [
          _buildAnimatedCard(_buildProfileCard(), delay: 0),
          _buildAnimatedCard(_buildAttendanceCard(), delay: 200),
          _buildAnimatedCard(_buildUploadCard(), delay: 400),
          if (_attendanceImage != null)
            _buildAnimatedCard(_buildLastRecordCard(), delay: 600),
          _buildAnimatedCard(_buildImprovementTipsCard(), delay: 800),
          _buildAnimatedCard(_buildChecklistCardButton(), delay: 1000),
          _buildAnimatedCard(_buildLogoutCard(), delay: 1200),
        ],
      ),
    );
  }

  Widget _buildAnimatedCard(Widget child, {int delay = 0}) {
    return Animate(
      effects: [
        FadeEffect(duration: 600.ms, delay: delay.ms),
        SlideEffect(
            begin: const Offset(0, 0.2),
            end: Offset.zero,
            duration: 600.ms,
            delay: delay.ms),
      ],
      child: child,
    );
  }

  // ------------------- Profile Card -------------------
  Widget _buildProfileCard() {
    double progress = (_completedHours / _requiredHours > 1)
        ? 1
        : _completedHours / _requiredHours;

    ImageProvider? profileImageProvider;
    if (_profileImage != null) {
      profileImageProvider = FileImage(_profileImage!);
    } else if (_profileImageBytes != null) {
      profileImageProvider = MemoryImage(_profileImageBytes!);
    }

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.orangeAccent, Colors.deepOrange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.orange.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Hero(
            tag: 'profile-photo',
            child: CircleAvatar(
              radius: 45,
              backgroundImage: profileImageProvider,
              backgroundColor: Colors.white,
              child: profileImageProvider == null
                  ? Image.network(
                      'https://cdn-icons-png.flaticon.com/512/3135/3135715.png',
                      height: 45,
                      color: Colors.orange,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_studentName ?? "Loading...",
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                Text("ID: ${_studentId ?? 'N/A'}",
                    style: const TextStyle(color: Colors.white)),
                Text("Course: ${_course ?? 'N/A'}",
                    style: const TextStyle(color: Colors.white)),
                Text("Coordinator: ${_coordinator ?? 'Pending'}",
                    style: const TextStyle(color: Colors.white)),
                Text("Supervisor: ${_supervisor ?? 'Pending'}",
                    style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  color: Colors.white,
                ),
                const SizedBox(height: 4),
                Text("OJT Hours: $_completedHours / $_requiredHours hrs",
                    style: const TextStyle(color: Colors.white)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------- Attendance Card -------------------
  Widget _buildAttendanceCard() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Image.network(
          'https://cdn-icons-png.flaticon.com/512/3515/3515523.png',
          height: 30,
        ),
        title: const Text(
          "Attendance Record",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text("View or update your daily attendance records"),
        trailing: Image.network(
          'https://cdn-icons-png.flaticon.com/512/271/271228.png',
          height: 20,
        ),
        onTap: () => _showAttendanceOptions(context),
      ),
    );
  }

  // ------------------- Last Attendance Record -------------------
  Widget _buildLastRecordCard() {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Image.network(
                  'https://cdn-icons-png.flaticon.com/512/747/747310.png',
                  height: 26,
                ),
                const SizedBox(width: 8),
                const Text(
                  "Last Attendance Record",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_lastActionTime != null)
              Row(
                children: [
                  Image.network(
                    'https://cdn-icons-png.flaticon.com/512/2088/2088617.png',
                    height: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _lastActionTime!,
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            if (_attendanceImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  _attendanceImage!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ).animate().fadeIn(duration: 600.ms).scale(),
              ),
          ],
        ),
      ),
    );
  }

  // ------------------- Upload Report -------------------
  Widget _buildUploadCard() {
    return _buildCardTemplate(
      iconUrl: 'https://cdn-icons-png.flaticon.com/512/992/992651.png',
      title: "Upload Progress Report",
      subtitle: "Submit your daily report after duty ends",
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const StudentProgressReportScreen(),
          ),
        );
      },
    );
  }

  // ------------------- Shared Card Template -------------------
  Widget _buildCardTemplate({
    required String iconUrl,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Image.network(iconUrl, height: 30),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------- Improvement Tips -------------------
  Widget _buildImprovementTipsCard() {
    return _buildCardTemplate(
      iconUrl: 'https://cdn-icons-png.flaticon.com/512/2721/2721276.png',
      title: "Get Improvement Tips",
      subtitle: "Receive suggestions to improve your OJT performance",
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text("🌟 OJT Improvement Tips"),
            content: const Text("💡 Keep improving daily with good habits!"),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Close"))
            ],
          ),
        );
      },
    );
  }

  // ------------------- Checklist -------------------
  Widget _buildChecklistCardButton() {
    return _buildCardTemplate(
      iconUrl: 'https://cdn-icons-png.flaticon.com/512/1828/1828640.png',
      title: "OJT Application Checklist",
      subtitle: "View and upload required OJT documents",
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => const StudentChecklistScreen()),
        );
      },
    );
  }

  // ------------------- Logout Card -------------------
  Widget _buildLogoutCard() {
    return _buildCardTemplate(
      iconUrl: 'https://cdn-icons-png.flaticon.com/512/1828/1828490.png',
      title: "Log Out",
      subtitle: "Sign out from your account",
      onTap: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Confirm Logout"),
            content: const Text("Are you sure you want to log out?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style:
                    ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text("Logout"),
              ),
            ],
          ),
        );

        if (confirm == true) {
          setState(() => _isLoading = true); // ✅ Show loading animation

          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();

          await Future.delayed(const Duration(seconds: 2)); // Simulated delay

          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
          );
        }
      },
    );
  }

  void _showAttendanceOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Image.network(
                  'https://cdn-icons-png.flaticon.com/512/2921/2921222.png',
                  height: 30,
                ),
                title: const Text("Record Attendance"),
                subtitle: const Text("Open camera to take attendance photo"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const StudentAttendanceScreen()),
                  );
                },
              ),
              ListTile(
                leading: Image.network(
                  'https://cdn-icons-png.flaticon.com/512/1828/1828415.png',
                  height: 30,
                ),
                title: const Text("View DTR"),
                subtitle: const Text("Check your Daily Time Record"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StudentDTRViewScreen(
                        studentName: _studentName ?? "Unknown",
                        studentId: _studentId ?? "N/A",
                        course: _course ?? "N/A",
                        dtrRecords: _dtrRecords,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Uint8List? _decodeProfilePhoto(String? photo) {
    if (photo == null || photo.isEmpty) return null;
    try {
      final sanitized =
          photo.contains(',') ? photo.split(',').last.trim() : photo.trim();
      return base64Decode(sanitized);
    } catch (_) {
      return null;
    }
  }
}
