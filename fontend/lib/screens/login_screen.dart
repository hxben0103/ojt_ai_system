import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/network_discovery_service.dart';
import '../core/app_theme.dart';
import '../core/config.dart';
import '../core/ai_config.dart';
import '../core/dio_client.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  bool _obscurePass = true;
  bool _isLoggingIn = false;
  bool _serverConnected = false;
  bool _checkingConnection = true;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Keep only admin demo account for testing
  final Map<String, String> _adminAccount = {
    "id": "admin",
    "password": "admin",
  };

  @override
  void initState() {
    super.initState();
    _loadRememberedID();
    _discoverAndCheckServer();

    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
            .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart));

    _controller.forward();
  }

  /// Auto-discover backend via UDP broadcast, then check connectivity
  Future<void> _discoverAndCheckServer() async {
    setState(() => _checkingConnection = true);

    // Try UDP broadcast discovery first
    await NetworkDiscoveryService.discoverServer();

    // Then verify the server is actually reachable
    final isHealthy = await NetworkDiscoveryService.checkHealth();
    if (mounted) {
      setState(() {
        _serverConnected = isHealthy;
        _checkingConnection = false;
      });

      // If not connected and no custom IP saved, auto-show settings dialog
      if (!isHealthy) {
        final hasIp = await ApiConfig.hasCustomIp();
        if (!hasIp && mounted) {
          _showIpSettingsDialog();
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadRememberedID() async {
    final prefs = await SharedPreferences.getInstance();
    final savedID = prefs.getString('saved_id');
    final remember = prefs.getBool('remember_me') ?? false;

    if (remember && savedID != null) {
      setState(() {
        _rememberMe = true;
        _idController.text = savedID;
      });
    }
  }

  Future<void> _saveRememberedID() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('saved_id', _idController.text.trim());
      await prefs.setBool('remember_me', true);
    } else {
      await prefs.remove('saved_id');
      await prefs.setBool('remember_me', false);
    }
  }

  void _navigateToDashboard(String role) {
    final normalizedRole = role.trim().toLowerCase();

    if (normalizedRole.contains('admin')) {
      Navigator.pushReplacementNamed(context, '/admin');
    } else if (normalizedRole.contains('coordinator')) {
      Navigator.pushReplacementNamed(context, '/coordinator');
    } else if (normalizedRole.contains('supervisor')) {
      Navigator.pushReplacementNamed(context, '/supervisor');
    } else if (normalizedRole.contains('student')) {
      Navigator.pushReplacementNamed(context, '/student');
    } else {
      Navigator.pushReplacementNamed(context, '/student');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Unknown role '$role'. Loaded student dashboard."),
        ),
      );
    }
  }

  void _login() async {
    String id = _idController.text.trim();
    String pass = _passwordController.text.trim();

    if (id.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter ID/Email and password")),
      );
      return;
    }

    setState(() => _isLoggingIn = true);

    // Admin demo account (for testing only)
    if (id == _adminAccount["id"] && pass == _adminAccount["password"]) {
      try {
        await Future.delayed(const Duration(milliseconds: 1000)); // Smooth feel
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', '{"user_id":0,"full_name":"Admin User","email":"admin@ojt.system","role":"Admin","status":"Active"}');
        await _saveRememberedID();
        if (mounted) _navigateToDashboard("Admin");
        return;
      } catch (e) {
        await _saveRememberedID();
        if (mounted) _navigateToDashboard("Admin");
        return;
      } finally {
        if (mounted) setState(() => _isLoggingIn = false);
      }
    }

    // For all other users, use real API authentication
    try {
      final response = await AuthService.login(
        identifier: id,
        password: pass,
      );

      if (response['user'] != null) {
        final userRole = response['user']['role'] as String;
        await _saveRememberedID();
        if (mounted) _navigateToDashboard(userRole);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Login failed. Please check your credentials.")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login error: ${e.toString()}")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  void _showRegisterOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.borderRadiusXL)),
          ),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text("Register As", style: AppTheme.heading2),
              const SizedBox(height: 24),

              // Student
              _buildRegisterTile(
                icon: Icons.school_rounded,
                color: AppTheme.studentPrimary,
                title: "Student",
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/register_student');
                },
              ),

              // OJT Coordinator
              _buildRegisterTile(
                icon: Icons.business_center_rounded,
                color: AppTheme.coordinatorPrimary,
                title: "OJT Coordinator",
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/register_coordinator');
                },
              ),

              // Industry Supervisor
              _buildRegisterTile(
                icon: Icons.supervised_user_circle_rounded,
                color: AppTheme.supervisorPrimary,
                title: "Industry Supervisor",
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/register_supervisor');
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRegisterTile({
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
      ),
      child: ListTile(
        leading: Icon(icon, color: color, size: 28),
        title: Text(title, style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w600, color: color)),
        trailing: Icon(Icons.arrow_forward_ios, size: 14, color: color.withOpacity(0.5)),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium)),
      ),
    );
  }

  void _showIpSettingsDialog() {
    final ipController = TextEditingController();
    
    // Attempt to extract the current IP from baseUrl 
    // Example: "http://192.168.0.117:3000/api" -> matches "192.168.0.117"
    String currentIp = '';
    final ipRegExp = RegExp(r'http://([0-9\.]+):');
    final match = ipRegExp.firstMatch(ApiConfig.baseUrl);
    if (match != null) {
      currentIp = match.group(1) ?? '';
    }
    ipController.text = currentIp;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge)),
          title: Row(
            children: [
              const Icon(Icons.wifi_tethering, color: Colors.blue),
              const SizedBox(width: 8),
              const Text('Server IP Configuration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter your computer\'s local IPv4 address (e.g., 192.168.1.10) so the app can connect to the backend over Wi-Fi.',
                style: AppTheme.bodySmall.copyWith(color: Colors.black87),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ipController,
                decoration: InputDecoration(
                  labelText: 'IP Address',
                  hintText: '192.168.x.x',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.computer_rounded),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                await ApiConfig.clearIp();
                await AiConfig.init(); // Reset to default
                DioClient().dio.options.baseUrl = ApiConfig.baseUrl; // Sync dio
                NetworkDiscoveryService.reset(); // Allow re-discovery
                if (mounted) {
                  Navigator.pop(ctx);
                  _discoverAndCheckServer(); // Re-discover
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("IP reset. Searching for server...")),
                  );
                }
              },
              child: const Text('Reset & Re-Discover', style: TextStyle(color: Colors.orange)),
            ),
            ElevatedButton(
              onPressed: () async {
                final ip = ipController.text.trim();
                if (ip.isNotEmpty) {
                  await ApiConfig.saveIp(ip);
                  AiConfig.setIp(ip);
                  DioClient().dio.options.baseUrl = ApiConfig.baseUrl; // Sync dio

                  // Test the connection before closing
                  final isHealthy = await NetworkDiscoveryService.checkHealth();
                  if (mounted) {
                    Navigator.pop(ctx);
                    setState(() => _serverConnected = isHealthy);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isHealthy
                            ? '✅ Connected to $ip successfully!'
                            : '⚠️ IP saved but server not reachable at $ip'),
                        backgroundColor: isHealthy ? Colors.green : Colors.orange,
                      ),
                    );
                  }
                }
              },
              style: AppTheme.primaryButtonStyle(Colors.blue),
              child: const Text('Save & Test'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF42A5F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Background decoration pattern could go here
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Top Right Settings Button with connection status
                          Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Connection status indicator
                                if (_checkingConnection)
                                  const SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(
                                      color: Colors.white70, strokeWidth: 2,
                                    ),
                                  )
                                else
                                  Container(
                                    width: 10, height: 10,
                                    decoration: BoxDecoration(
                                      color: _serverConnected ? Colors.greenAccent : Colors.redAccent,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: (_serverConnected ? Colors.greenAccent : Colors.redAccent).withOpacity(0.6),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.wifi_find_rounded, color: Colors.white70, size: 28),
                                  tooltip: _serverConnected
                                      ? 'Connected to ${ApiConfig.baseUrl}'
                                      : 'Server not reachable — tap to configure',
                                  onPressed: _showIpSettingsDialog,
                                ),
                              ],
                            ),
                          ),
                          // ✅ Modern Logo Section
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Image.asset('assets/images/logo.gif', height: 140),
                          ).animate().scale(delay: 200.ms, duration: 600.ms, curve: Curves.easeOutBack),
                          
                          const SizedBox(height: 12),
                          Text(
                            "JRMSU AI OJT",
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ).animate().fadeIn(delay: 400.ms),
                          
                          const SizedBox(height: 32),
                          
                          // ✅ Login Card
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(AppTheme.borderRadiusXL),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 30,
                                  offset: const Offset(0, 10),
                                )
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Welcome Back", style: AppTheme.heading2),
                                  const SizedBox(height: 8),
                                  Text("Sign in to your dashboard", style: AppTheme.bodyMedium.copyWith(color: Colors.black54)),
                                  const SizedBox(height: 32),

                                  // ID/Email Field
                                  TextField(
                                    controller: _idController,
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(Icons.badge_outlined),
                                      labelText: 'Student/Staff ID or Email',
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                                        borderSide: BorderSide.none,
                                      ),
                                    ),
                                    keyboardType: TextInputType.text,
                                  ),
                                  const SizedBox(height: 20),

                                  // Password Field
                                  TextField(
                                    controller: _passwordController,
                                    obscureText: _obscurePass,
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                                      labelText: 'Password',
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                                        borderSide: BorderSide.none,
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                          color: Colors.grey,
                                          size: 20,
                                        ),
                                        onPressed: () => setState(() => _obscurePass = !_obscurePass),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  Row(
                                    children: [
                                      SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: Checkbox(
                                          value: _rememberMe,
                                          activeColor: AppTheme.studentPrimary,
                                          onChanged: (value) => setState(() => _rememberMe = value ?? false),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text("Remember Me", style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w500)),
                                      const Spacer(),
                                      TextButton(
                                        onPressed: () {}, // Forgot password placeholder
                                        child: Text("Forgot?", style: AppTheme.bodySmall.copyWith(color: AppTheme.studentPrimary, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 32),

                                  // Login Button
                                  ElevatedButton(
                                    onPressed: _isLoggingIn ? null : _login,
                                    style: AppTheme.primaryButtonStyle(AppTheme.studentPrimary).copyWith(
                                      minimumSize: WidgetStateProperty.all(const Size(double.infinity, 56)),
                                      shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium))),
                                    ),
                                    child: _isLoggingIn
                                        ? const SizedBox(
                                            height: 24,
                                            width: 24,
                                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                          )
                                        : const Text("Sign In"),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 48),

                          // Register Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Don't have an account? ", style: TextStyle(color: Colors.white)),
                              TextButton(
                                onPressed: _showRegisterOptions,
                                child: const Text(
                                  "Create Account",
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

