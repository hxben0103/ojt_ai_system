import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/register_student.dart';
import 'screens/register_coordinator.dart';
import 'screens/register_supervisor.dart';
import 'dashboards/admin_dashboard.dart';
import 'dashboards/coordinator_dashboard.dart';
import 'dashboards/supervisor_dashboard.dart';
import 'dashboards/student_dashboard.dart';


void main() {
  runApp(const OjtAiApp());
}

class OjtAiApp extends StatelessWidget {
  const OjtAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI OJT Platform',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/admin': (context) => const AdminDashboard(),
        '/coordinator': (context) => const CoordinatorDashboard(),
        '/supervisor': (context) => const SupervisorDashboard(),
        '/student': (context) => const StudentDashboard(),


        // ✅ Separate Register Pages
        '/register_student': (context) => const RegisterStudent(),
        '/register_coordinator': (context) => const RegisterCoordinator(),
        '/register_supervisor': (context) => const RegisterSupervisor(),
      },
    );
    
  }
}
