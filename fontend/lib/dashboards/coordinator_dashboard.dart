import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/role_dashboard.dart';
import 'coordinator_student_monitor.dart';

class CoordinatorDashboard extends StatelessWidget {
  const CoordinatorDashboard({super.key});

  // Coordinator profile info
  final String fullName = "Ms. Angela Reyes";
  final String idNumber = "COORD001";
  final String office = "OJT Office";
  final String position = "OJT Coordinator";

  @override
  Widget build(BuildContext context) {
    return RoleDashboard(
      title: "OJT Coordinator Dashboard",
      color: Colors.deepPurple,
      tasks: const [],
      customActions: [
        _buildAnimatedCard(_buildProfileHeader(), delay: 0),
        _buildAnimatedCard(_buildFeatureCard(
          icon: Icons.checklist,
          title: "Track Student Tasks & Attendance",
          subtitle: "View students' progress and attendance records",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CoordinatorStudentMonitor()),
            );
          },
        ), delay: 200),
        _buildAnimatedCard(_buildFeatureCard(
          icon: Icons.feedback,
          title: "Review Supervisor Feedback",
          subtitle: "Check evaluations and feedback given by supervisors",
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Navigating to supervisor feedback screen...")),
            );
          },
        ), delay: 400),
        _buildAnimatedCard(_buildFeatureCard(
          icon: Icons.bar_chart,
          title: "Identify High/Low Performers",
          subtitle: "Analyze student performance metrics",
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Navigating to performance analysis screen...")),
            );
          },
        ), delay: 600),
        _buildAnimatedCard(_buildFeatureCard(
          icon: Icons.verified_user,
          title: "Approve OJT Accounts & Supervisors",
          subtitle: "Approve new student accounts and assigned supervisors",
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Navigating to account & supervisor approval...")),
            );
          },
        ), delay: 800),
        _buildAnimatedCard(_buildFeatureCard(
          icon: Icons.message,
          title: "Communicate with Users",
          subtitle: "Send announcements or messages to students and supervisors",
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Messaging functionality coming soon...")),
            );
          },
        ), delay: 1000),
        _buildAnimatedCard(_buildFeatureCard(
          icon: Icons.file_present,
          title: "Create Reports",
          subtitle: "Generate reports on OJT activities, attendance, and evaluations",
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Report generation screen coming soon...")),
            );
          },
        ), delay: 1200),
      ],
    );
  }

  // --- Animation Wrapper ---
  Widget _buildAnimatedCard(Widget child, {int delay = 0}) {
    return Animate(
      effects: [
        FadeEffect(duration: 600.ms, delay: delay.ms),
        SlideEffect(begin: const Offset(0, 0.2), end: Offset.zero, delay: delay.ms, duration: 600.ms),
      ],
      child: child,
    );
  }

  // --- Profile Header with Gradient ---
  Widget _buildProfileHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.deepPurpleAccent, Colors.deepPurple],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: Colors.white,
            child: Text(
              fullName.split(" ").map((e) => e[0]).take(2).join(),
              style: const TextStyle(
                  color: Colors.deepPurple, fontSize: 22, fontWeight: FontWeight.bold),
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
                Text("ID Number: $idNumber",
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

  // --- Reusable Feature Card ---
  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      shadowColor: Colors.deepPurple.withOpacity(0.3),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.deepPurple, size: 28),
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
              const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms).scale(delay: 100.ms);
  }
}
