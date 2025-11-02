import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/role_dashboard.dart';
import 'supervisor_student_monitor.dart';

class SupervisorDashboard extends StatelessWidget {
  const SupervisorDashboard({super.key});

  // Sample supervisor profile info
  final String fullName = "Engr. Carlos Mendoza";
  final String idNumber = "SUP001";
  final String office = "IT Department";
  final String position = "Industry Supervisor";

  // Sample student data (for monitoring)
  final List<Map<String, dynamic>> students = const [
    {"name": "Juan Dela Cruz", "completedHours": 300, "requiredHours": 300},
    {"name": "Maria Santos", "completedHours": 150, "requiredHours": 300},
    {"name": "Pedro Reyes", "completedHours": 280, "requiredHours": 300},
  ];

  @override
  Widget build(BuildContext context) {
    return RoleDashboard(
      title: "Industry Supervisor Dashboard",
      color: Colors.teal,
      tasks: const [],
      customActions: [
        _buildAnimated(_buildProfileHeader(), 0),
        _buildAnimated(_buildFeatureCard(
          icon: Icons.check_circle_outline,
          title: "Auto Check Completed OJT Hours",
          subtitle: "Tap to see students who have completed their required hours",
          onTap: () {
            List<String> completedStudents = students
                .where((s) => s['completedHours'] >= s['requiredHours'])
                .map((s) => s['name'] as String)
                .toList();

            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text("Completed Students"),
                content: completedStudents.isNotEmpty
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: completedStudents
                            .map((name) => ListTile(
                                  leading: const Icon(Icons.check, color: Colors.teal),
                                  title: Text(name),
                                ))
                            .toList(),
                      )
                    : const Text("No students have completed their OJT hours yet."),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Close"),
                  )
                ],
              ),
            );
          },
        ), 200),
        _buildAnimated(_buildFeatureCard(
          icon: Icons.assignment_turned_in,
          title: "Submit Evaluations",
          subtitle: "Evaluate students and submit feedback",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SupervisorStudentMonitorScreen(),
              ),
            );
          },
        ), 400),
        _buildAnimated(_buildFeatureCard(
          icon: Icons.monitor_heart,
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
          icon: Icons.message,
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
              fullName.split(" ").map((e) => e[0]).take(2).join(),
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

  // --- Reusable Feature Card ---
  Widget _buildFeatureCard({
    required IconData icon,
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
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.teal, size: 28),
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
