import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/role_dashboard.dart';
import 'student_checklist_screen.dart';
import 'student_attendance_screen.dart';
import 'student_dtr_view_screen.dart';
import 'package:flutter_application_1/screens/login_screen.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard>
    with SingleTickerProviderStateMixin {
  File? _attendanceImage;
  File? _profileImage;
  bool _isTimedIn = false;
  String? _lastActionTime;
  int _completedHours = 0;
  int _requiredHours = 300;
  final picker = ImagePicker();

  String? _studentName;
  String? _studentId;
  String? _course;
  String? _coordinator;
  String? _supervisor;

  List<Map<String, dynamic>> _dtrRecords = [];

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
    _loadAttendanceData();
    _loadDTRRecords();

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

  // ------------------- Loaders -------------------
  Future<void> _loadStudentData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _studentName = prefs.getString('student_name') ?? "Unknown";
      _studentId = prefs.getString('student_id') ?? "N/A";
      _course = prefs.getString('student_course') ?? "N/A";
      _coordinator = prefs.getString('student_coordinator') ?? "Pending";
      _supervisor = prefs.getString('student_supervisor') ?? "Pending";
      _requiredHours = prefs.getInt('student_required_hours') ?? 300;

      final profilePath = prefs.getString('student_photo');
      if (profilePath != null && File(profilePath).existsSync()) {
        _profileImage = File(profilePath);
      }
    });
  }

  Future<void> _loadAttendanceData() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString('attendance_image');
    final isTimedIn = prefs.getBool('is_timed_in') ?? false;
    final lastTime = prefs.getString('last_action_time');
    final completedHours = prefs.getInt('completed_hours') ?? 0;

    setState(() {
      _isTimedIn = isTimedIn;
      _lastActionTime = lastTime;
      _completedHours = completedHours;
      if (imagePath != null && File(imagePath).existsSync()) {
        _attendanceImage = File(imagePath);
      }
    });
  }

  Future<void> _loadDTRRecords() async {
    setState(() {
      _dtrRecords = [
        {
          'date': '2025-11-03',
          'amIn': '08:00 AM',
          'amOut': '12:00 PM',
          'pmIn': '01:00 PM',
          'pmOut': '05:00 PM',
          'otIn': '-',
          'otOut': '-',
          'totalHours': '8',
        },
      ];
    });
  }

  // ------------------- UI -------------------
  @override
  Widget build(BuildContext context) {
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
              backgroundImage:
                  _profileImage != null ? FileImage(_profileImage!) : null,
              backgroundColor: Colors.white,
              child: _profileImage == null
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
                  'https://cdn-icons-png.flaticon.com/512/747/747310.png', // calendar icon
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
                    'https://cdn-icons-png.flaticon.com/512/2088/2088617.png', // clock icon
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
        if (_lastActionTime == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content:
                  Text("⚠️ Please record your attendance before uploading.")));
          return;
        }
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
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();

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
}
