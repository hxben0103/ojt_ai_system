import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart'; // 👈 for animations
import '../widgets/role_dashboard.dart';
import 'student_checklist_screen.dart';

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

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
    _loadAttendanceData();

    // 👇 Animation controller for fade-in
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

  Future<void> _saveAttendance(
      String imagePath, bool isTimedIn, String timeText) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('attendance_image', imagePath);
    await prefs.setBool('is_timed_in', isTimedIn);
    await prefs.setString('last_action_time', timeText);
    await prefs.setInt('completed_hours', _completedHours);
  }

  Future<bool> _requestCameraPermission() async {
    var status = await Permission.camera.status;
    if (status.isGranted) return true;
    status = await Permission.camera.request();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) openAppSettings();
    return false;
  }

  // ------------------- Time In/Out -------------------
  Future<void> _handleAttendance() async {
    bool granted = await _requestCameraPermission();
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Camera permission required.")),
      );
      return;
    }

    try {
      final XFile? image =
          await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
      if (image != null) {
        String timeNow =
            DateFormat('hh:mm a, MMM d yyyy').format(DateTime.now());
        setState(() {
          _attendanceImage = File(image.path);
          _isTimedIn = !_isTimedIn;
          _lastActionTime = timeNow;
          if (!_isTimedIn) _completedHours += 8;
        });

        await _saveAttendance(image.path, _isTimedIn, timeNow);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isTimedIn
                ? "✅ Time In successful at $timeNow"
                : "✅ Time Out successful at $timeNow"),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ Camera error: $e")),
      );
    }
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
                  ? const Icon(Icons.person, size: 45, color: Colors.orange)
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

  Widget _buildAttendanceCard() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(_isTimedIn ? Icons.logout : Icons.login,
            color: Colors.orange, size: 30),
        title: Text(
          _isTimedIn ? "Time Out (End Duty)" : "Time In (Start Duty)",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text("Tap to record attendance using camera"),
        trailing: const Icon(Icons.camera_alt, color: Colors.grey),
        onTap: _handleAttendance,
      ),
    );
  }

  Widget _buildUploadCard() {
    return _buildCardTemplate(
      icon: Icons.upload_file,
      title: "Upload Progress Report",
      subtitle: "Submit your daily report after duty ends",
      onTap: () {
        if (_isTimedIn) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content:
                  Text("⚠️ You must Time Out first before uploading your report.")));
          return;
        }
        if (_lastActionTime == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text("⚠️ Please complete Time In/Out first.")));
          return;
        }
      },
    );
  }

  Widget _buildCardTemplate({
    required IconData icon,
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
              Icon(icon, color: Colors.orange, size: 30),
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

  Widget _buildImprovementTipsCard() {
    final List<String> tips = [
      "💡 Always arrive early and prepare your materials before starting your tasks.",
      "🗣️ Communicate proactively with your supervisor about challenges and progress.",
      "📋 Keep a daily journal of what you’ve learned.",
      "🤝 Show initiative — ask for extra tasks or responsibilities.",
      "🧠 Learn about your company’s workflow.",
      "🕒 Manage your time efficiently — prioritize urgent tasks.",
      "✨ Dress and behave professionally.",
      "📈 Review your daily reports and improve each day.",
    ];

    return _buildCardTemplate(
      icon: Icons.lightbulb_outline,
      title: "Get Improvement Tips",
      subtitle: "Receive suggestions to improve your OJT performance",
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text("🌟 OJT Improvement Tips"),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: tips.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(tips[index],
                            style: const TextStyle(fontSize: 15, height: 1.4)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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

  Widget _buildLastRecordCard() {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("📅 Last Attendance Record",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_lastActionTime != null)
              Text("🕒 $_lastActionTime",
                  style: const TextStyle(fontSize: 16, color: Colors.black87)),
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

  Widget _buildChecklistCardButton() {
    return _buildCardTemplate(
      icon: Icons.checklist,
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
}
