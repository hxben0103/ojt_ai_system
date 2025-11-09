import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/role_dashboard.dart';
import 'package:flutter_application_1/screens/login_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleDashboard(
      title: "Admin Dashboard",
      color: Colors.indigo,
      tasks: const [],
      customActions: [
        _buildCardTemplate(
          icon: Icons.verified_user,
          title: "Approve OJT Coordinator",
          subtitle: "Review and approve coordinator accounts",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ApproveCoordinatorScreen(),
              ),
            );
          },
        ),
        _buildCardTemplate(
          icon: Icons.logout,
          title: "Logout",
          subtitle: "Sign out from admin account",
          iconColor: Colors.red,
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
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text("Logout"),
                  ),
                ],
              ),
            );

            if (confirm == true) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();

              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            }
          },
        ),
      ],
    );
  }

  // 🔹 Reusable card template
  static Widget _buildCardTemplate({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color iconColor = Colors.indigo,
  }) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 30),
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
}

// -----------------------------------------------------------------------------
// ✅ Empty screen placeholder for Approve Coordinator (no demo data)
// -----------------------------------------------------------------------------
class ApproveCoordinatorScreen extends StatelessWidget {
  const ApproveCoordinatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Approve OJT Coordinators"),
        backgroundColor: Colors.indigo,
      ),
      body: const Center(
        child: Text(
          "No pending coordinator approvals yet.",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
    );
  }
}
