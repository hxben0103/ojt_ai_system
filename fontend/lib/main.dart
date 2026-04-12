import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/app_theme.dart';
import 'core/config.dart';
import 'core/ai_config.dart';
import 'services/network_discovery_service.dart';
import 'screens/login_screen.dart';
import 'screens/register_student.dart';
import 'screens/register_coordinator.dart';
import 'screens/register_supervisor.dart';
import 'dashboards/admin_dashboard.dart';
import 'dashboards/coordinator_dashboard.dart';
import 'dashboards/supervisor_dashboard.dart';
import 'dashboards/student_dashboard.dart';
import 'providers/student_provider.dart';
import 'providers/coordinator_provider.dart';
import 'providers/supervisor_provider.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Auto-discover backend via mDNS first, fall back to cached/default IP
  await NetworkDiscoveryService.discoverServer();
  runApp(const OjtAiApp());
}

class OjtAiApp extends StatelessWidget {
  const OjtAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StudentProvider()),
        ChangeNotifierProvider(create: (_) => CoordinatorProvider()),
        ChangeNotifierProvider(create: (_) => SupervisorProvider()),
        ChangeNotifierProvider(create: (_) => NotificationService()),
      ],
      child: MaterialApp(
        title: 'AI OJT Platform',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const SplashScreen(), // 👈 Start with splash
        routes: {
          '/login': (context) => const LoginScreen(),
          '/admin': (context) => const AdminDashboard(),
          '/coordinator': (context) => const CoordinatorDashboard(),
          '/supervisor': (context) => const SupervisorDashboard(),
          '/student': (context) => const StudentDashboard(),
          '/register_student': (context) => const RegisterStudent(),
          '/register_coordinator': (context) => const RegisterCoordinator(),
          '/register_supervisor': (context) => const RegisterSupervisor(),
        },
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 🌟 Animated Splash Screen with your ojt.png Logo
// -----------------------------------------------------------------------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Animation setup
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _scaleAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    _controller.forward();

    // Navigate to LoginScreen after delay
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ✅ Splash UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo.shade700,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 🔹 Your actual logo image
                Image.asset(
                  'assets/images/logo.gif', height: 220),
                const SizedBox(height: 25),
                
              ],
            ),
          ),
        ),
      ),
    );
  }
}
