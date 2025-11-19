import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/role_dashboard.dart';
import '../widgets/role_guard.dart';
import 'supervisor_student_monitor.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import '../services/auth_service.dart';
import '../models/user.dart';
import '../screens/supervisor/supervisor_evaluation_form_screen.dart';

class SupervisorDashboard extends StatefulWidget {
  const SupervisorDashboard({super.key});

  @override
  State<SupervisorDashboard> createState() => _SupervisorDashboardState();
}

class _SupervisorDashboardState extends State<SupervisorDashboard> {
  // Profile info will be loaded from API
  String fullName = "Loading...";
  String idNumber = "N/A";
  String office = "N/A";
  String position = "Industry Supervisor";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user != null) {
        setState(() {
          fullName = user.fullName;
          idNumber = user.studentId ?? user.email;
          office = user.course ?? "N/A";
          position = user.role;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allowedRoles: const ['supervisor', 'industry supervisor'],
      builder: (ctx, user) => _buildSupervisorDashboard(ctx),
    );
  }

  Widget _buildSupervisorDashboard(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return RoleDashboard(
      title: "Industry Supervisor Dashboard",
      color: Colors.teal,
      tasks: const [],
      customActions: [
        _buildAnimated(_buildProfileHeader(), 0),
        _buildAnimated(_buildFeatureCard(
          iconUrl: "https://cdn-icons-png.flaticon.com/512/992/992700.png",
          title: "Auto Check Completed OJT Hours",
          subtitle: "Tap to see students who have completed their required hours",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SupervisorStudentMonitorScreen(),
              ),
            );
          },
        ), 200),
        _buildAnimated(_buildFeatureCard(
          iconUrl: "https://cdn-icons-png.flaticon.com/512/2838/2838912.png",
          title: "Submit Evaluations",
          subtitle: "Evaluate students and submit feedback",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SupervisorEvaluationFormScreen(),
              ),
            );
          },
        ), 400),
        _buildAnimated(_buildFeatureCard(
          iconUrl: "https://cdn-icons-png.flaticon.com/512/5974/5974636.png",
          title: "Monitor Student Behavior",
          subtitle: "Track OJT hours and progress of students",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SupervisorStudentMonitorScreen(),
              ),
            );
          },
        ), 600),
        _buildAnimated(_buildFeatureCard(
          iconUrl: "https://cdn-icons-png.flaticon.com/512/561/561127.png",
          title: "Message Students/Coordinators",
          subtitle: "Send announcements or complaints",
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Messaging feature will be implemented here."),
              ),
            );
          },
        ), 800),

        // ✅ Logout Card Added
        _buildAnimated(_buildLogoutCard(context), 1000),
      ],
    );
  }

  

  // --- Animated Wrapper ---
  Widget _buildAnimated(Widget child, int delay) {
    return Animate(
      effects: [
        FadeEffect(duration: 600.ms, delay: delay.ms),
        SlideEffect(begin: const Offset(0, 0.2), end: Offset.zero, delay: delay.ms),
      ],
      child: child,
    );
  }

  // --- Profile Header with Gradient & Shadow ---
  Widget _buildProfileHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.teal, Colors.tealAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: Colors.white,
            child: Text(
              fullName.split(" ").where((e) => e.isNotEmpty).map((e) => e[0]).take(2).join(),
              style: const TextStyle(
                color: Colors.teal,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fullName,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 6),
                Text("ID: $idNumber",
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
                Text("Office: $office",
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
                Text("Position: $position",
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Reusable Feature Card (with Network Icon) ---
  Widget _buildFeatureCard({
    required String iconUrl,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 6,
      shadowColor: Colors.teal.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        splashColor: Colors.teal.withOpacity(0.2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.network(iconUrl, height: 28, width: 28),
              ),
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
              Image.network(
                "https://cdn-icons-png.flaticon.com/512/271/271228.png",
                height: 18,
                width: 18,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).scale(delay: 100.ms);
  }

      // --- Logout Card (with White Background Loading Animation) ---
  Widget _buildLogoutCard(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shadowColor: Colors.teal.withOpacity(0.3),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Confirm Logout"),
              content:
                  const Text("Are you sure you want to log out of your account?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text("Logout"),
                ),
              ],
            ),
          );

          if (confirm == true) {
            // ✅ Show loading animation dialog with white background
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => Scaffold(
                backgroundColor: Colors.white, // White background
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/logo.gif', // your logo or loading GIF
                        height: 200,
                      )
                          .animate()
                          .fadeIn(duration: 900.ms)
                          .scale(duration: 900.ms),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            );

            // Simulate delay for logout
            await Future.delayed(const Duration(seconds: 2));

            final prefs = await SharedPreferences.getInstance();
            await prefs.clear();

            if (context.mounted) {
              Navigator.pop(context); // Close loading dialog
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            }
          }
        },
        child: ListTile(
          leading: Image.network(
            "https://cdn-icons-png.flaticon.com/512/1828/1828490.png",
            height: 28,
            width: 28,
          ),
          title: const Text(
            "Log Out",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: const Text("Sign out from your account"),
          trailing: Image.network(
            "https://cdn-icons-png.flaticon.com/512/271/271228.png",
            height: 18,
            width: 18,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}
