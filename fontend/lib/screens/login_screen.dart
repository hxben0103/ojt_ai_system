import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = "Student";
  bool _rememberMe = false;
  bool _obscurePass = true;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final Map<String, Map<String, String>> _accounts = {
    "Admin": {"id": "admin", "password": "admin"},
    "Student": {"id": "1", "password": "1"},
    "OJT Coordinator": {"id": "1", "password": "1"},
    "Industry Supervisor": {"id": "1", "password": "1"},
  };

  @override
  void initState() {
    super.initState();
    _loadRememberedID();

    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
            .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
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
    switch (role) {
      case "OJT Coordinator":
        Navigator.pushReplacementNamed(context, '/coordinator');
        break;
      case "Industry Supervisor":
        Navigator.pushReplacementNamed(context, '/supervisor');
        break;
      case "Admin":
        Navigator.pushReplacementNamed(context, '/admin');
        break;
      default:
        Navigator.pushReplacementNamed(context, '/student');
    }
  }

  void _login() async {
    String id = _idController.text.trim();
    String pass = _passwordController.text.trim();

    if (id.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter ID number and password")),
      );
      return;
    }

    if (id == _accounts["Admin"]!["id"] &&
        pass == _accounts["Admin"]!["password"]) {
      await _saveRememberedID();
      _navigateToDashboard("Admin");
      return;
    }

    final roleAccount = _accounts[_selectedRole];
    if (roleAccount != null &&
        id == roleAccount["id"] &&
        pass == roleAccount["password"]) {
      await _saveRememberedID();
      _navigateToDashboard(_selectedRole);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid ID number or password")),
      );
    }
  }

  void _showRegisterOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Register As",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              // Student
              ListTile(
                leading: Image.network(
                  'https://cdn-icons-png.flaticon.com/512/3135/3135755.png',
                  height: 28,
                ),
                title: const Text("Student"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/register_student');
                },
              ),

              // OJT Coordinator
              ListTile(
                leading: Image.network(
                  'https://cdn-icons-png.flaticon.com/512/3135/3135715.png',
                  height: 28,
                ),
                title: const Text("OJT Coordinator"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/register_coordinator');
                },
              ),

              // Industry Supervisor
              ListTile(
                leading: Image.network(
                  'https://cdn-icons-png.flaticon.com/512/1995/1995574.png',
                  height: 28,
                ),
                title: const Text("Industry Supervisor"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/register_supervisor');
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF3F51B5), Color(0xFF7986CB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Card(
                    elevation: 12,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ✅ Animated Logo
                          AnimatedScale(
                            scale: 1.1,
                            duration: const Duration(seconds: 1),
                            curve: Curves.elasticOut,
                            child: Image.asset('assets/images/logo.gif',
                                height: 150),
                          ),
                          const SizedBox(height: 20),

                          // ✅ Role Selector
                          DropdownButtonFormField<String>(
                            value: _selectedRole,
                            decoration: const InputDecoration(
                              labelText: "Select Role",
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: "Student", child: Text("Student")),
                              DropdownMenuItem(
                                  value: "OJT Coordinator",
                                  child: Text("OJT Coordinator")),
                              DropdownMenuItem(
                                  value: "Industry Supervisor",
                                  child: Text("Industry Supervisor")),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _selectedRole = value!;
                              });
                            },
                          ),
                          const SizedBox(height: 16),

                          TextField(
                            controller: _idController,
                            decoration: const InputDecoration(
                              labelText: 'ID Number',
                              hintText: 'Enter your ID number',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),

                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePass,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Image.network(
                                  _obscurePass
                                      ? 'https://cdn-icons-png.flaticon.com/512/565/565655.png' // hidden eye
                                      : 'https://cdn-icons-png.flaticon.com/512/565/565654.png', // visible eye
                                  height: 22,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePass = !_obscurePass;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Checkbox(
                                value: _rememberMe,
                                activeColor: Colors.indigo,
                                onChanged: (value) {
                                  setState(() {
                                    _rememberMe = value ?? false;
                                  });
                                },
                              ),
                              const Text("Remember my ID",
                                  style: TextStyle(fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 20),

                          ElevatedButton(
                            onPressed: _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              elevation: 5,
                            ),
                            child: const Text("Login",
                                style: TextStyle(fontSize: 18)),
                          ),
                          const SizedBox(height: 16),

                          TextButton(
                            onPressed: _showRegisterOptions,
                            child: const Text(
                              "Don't have an account? Register here",
                              style: TextStyle(
                                  fontSize: 16, color: Colors.indigoAccent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
