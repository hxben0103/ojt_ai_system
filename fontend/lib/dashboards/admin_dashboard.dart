import 'package:flutter/material.dart';
import '../widgets/role_dashboard.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleDashboard(
      title: "Admin Dashboard",
      color: Colors.indigo,
      tasks: const [
        "Add & Verify Users",
        "Monitor System Activity",
        "Configure AI Settings",
        "Generate Reports",
        "Manage System Setup",
      ],
    );
  }
}
