import 'package:flutter/material.dart';
import 'dart:async';
import '../services/auth_service.dart';

class RegisterSupervisor extends StatefulWidget {
  const RegisterSupervisor({super.key});

  @override
  State<RegisterSupervisor> createState() => _RegisterSupervisorState();
}

class _RegisterSupervisorState extends State<RegisterSupervisor>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _fullNameController = TextEditingController();
  final _idController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _officeController = TextEditingController();
  final _positionController = TextEditingController();
  final _locationController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _showPassword = false;
  bool _isLoading = false;
  String? _selectedGender;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match!")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final fullName = _fullNameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (fullName.isEmpty || email.isEmpty || password.isEmpty) {
        throw Exception('Please fill in all required fields');
      }

      await AuthService.register(
        fullName: fullName,
        email: email,
        password: password,
        role: 'Supervisor',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "Registration submitted successfully! Please wait for OJT Coordinator approval."),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _fullNameController.dispose();
    _idController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _officeController.dispose();
    _positionController.dispose();
    _locationController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Widget animatedField(Widget child, int index) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, 0.1 * (index + 1)),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _animController,
          curve: Curves.easeOutCubic,
        )),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text("Industry Supervisor Registration"),
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: Image.network(
                'https://cdn-icons-png.flaticon.com/512/507/507257.png',
                height: 26,
                color: Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3F51B5), Color(0xFF5C6BC0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 8,
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              Image.network(
                                'https://cdn-icons-png.flaticon.com/512/3135/3135715.png',
                                height: 90,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                "Supervisor Registration",
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo,
                                ),
                              ),
                              const SizedBox(height: 20),

                              // ✅ Fields
                              animatedField(
                                TextFormField(
                                  controller: _fullNameController,
                                  decoration: InputDecoration(
                                    labelText: 'Full Name',
                                    border: const OutlineInputBorder(),
                                    prefixIcon: Image.network(
                                      'https://cdn-icons-png.flaticon.com/512/1077/1077114.png',
                                      height: 20,
                                    ),
                                  ),
                                  validator: (v) => v!.isEmpty
                                      ? "Please enter your full name"
                                      : null,
                                ),
                                1,
                              ),
                              animatedField(
                                TextFormField(
                                  controller: _idController,
                                  decoration: InputDecoration(
                                    labelText:
                                        'Supervisor ID Number (for login)',
                                    border: const OutlineInputBorder(),
                                    prefixIcon: Image.network(
                                      'https://cdn-icons-png.flaticon.com/512/3064/3064197.png',
                                      height: 20,
                                    ),
                                  ),
                                  validator: (v) => v!.isEmpty
                                      ? "Please enter your ID number"
                                      : null,
                                ),
                                2,
                              ),
                              animatedField(
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    labelText: 'Email Address',
                                    border: const OutlineInputBorder(),
                                    prefixIcon: Image.network(
                                      'https://cdn-icons-png.flaticon.com/512/732/732200.png',
                                      height: 20,
                                    ),
                                  ),
                                  validator: (v) => v!.isEmpty
                                      ? "Please enter your email"
                                      : null,
                                ),
                                3,
                              ),
                              animatedField(
                                DropdownButtonFormField<String>(
                                  value: _selectedGender,
                                  decoration: InputDecoration(
                                    labelText: "Gender",
                                    border: const OutlineInputBorder(),
                                    prefixIcon: Image.network(
                                      'https://cdn-icons-png.flaticon.com/512/1250/1250689.png',
                                      height: 20,
                                    ),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                        value: "Male", child: Text("Male")),
                                    DropdownMenuItem(
                                        value: "Female", child: Text("Female")),
                                  ],
                                  onChanged: (value) =>
                                      setState(() => _selectedGender = value),
                                  validator: (v) => v == null
                                      ? "Please select your gender"
                                      : null,
                                ),
                                4,
                              ),
                              animatedField(
                                TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  decoration: InputDecoration(
                                    labelText: 'Phone Number',
                                    border: const OutlineInputBorder(),
                                    prefixIcon: Image.network(
                                      'https://cdn-icons-png.flaticon.com/512/15/15874.png',
                                      height: 20,
                                    ),
                                  ),
                                  validator: (v) => v!.isEmpty
                                      ? "Please enter your phone number"
                                      : null,
                                ),
                                5,
                              ),
                              animatedField(
                                TextFormField(
                                  controller: _officeController,
                                  decoration: InputDecoration(
                                    labelText: 'Office / Department',
                                    border: const OutlineInputBorder(),
                                    prefixIcon: Image.network(
                                      'https://cdn-icons-png.flaticon.com/512/1006/1006542.png',
                                      height: 20,
                                    ),
                                  ),
                                  validator: (v) => v!.isEmpty
                                      ? "Please enter your office name"
                                      : null,
                                ),
                                6,
                              ),
                              animatedField(
                                TextFormField(
                                  controller: _positionController,
                                  decoration: InputDecoration(
                                    labelText: 'Position / Role',
                                    border: const OutlineInputBorder(),
                                    prefixIcon: Image.network(
                                      'https://cdn-icons-png.flaticon.com/512/3135/3135789.png',
                                      height: 20,
                                    ),
                                  ),
                                  validator: (v) => v!.isEmpty
                                      ? "Please enter your position"
                                      : null,
                                ),
                                7,
                              ),
                              animatedField(
                                TextFormField(
                                  controller: _locationController,
                                  decoration: InputDecoration(
                                    labelText: 'Office Location / Address',
                                    border: const OutlineInputBorder(),
                                    prefixIcon: Image.network(
                                      'https://cdn-icons-png.flaticon.com/512/854/854878.png',
                                      height: 20,
                                    ),
                                  ),
                                  validator: (v) => v!.isEmpty
                                      ? "Please enter office location"
                                      : null,
                                ),
                                8,
                              ),
                              animatedField(
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: !_showPassword,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    border: const OutlineInputBorder(),
                                    prefixIcon: Image.network(
                                      'https://cdn-icons-png.flaticon.com/512/1000/1000966.png',
                                      height: 20,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Image.network(
                                        _showPassword
                                            ? 'https://cdn-icons-png.flaticon.com/512/709/709612.png'
                                            : 'https://cdn-icons-png.flaticon.com/512/709/709724.png',
                                        height: 22,
                                      ),
                                      onPressed: () => setState(() =>
                                          _showPassword = !_showPassword),
                                    ),
                                  ),
                                  validator: (v) => v!.isEmpty
                                      ? "Please enter your password"
                                      : null,
                                ),
                                9,
                              ),
                              animatedField(
                                TextFormField(
                                  controller: _confirmPasswordController,
                                  obscureText: !_showPassword,
                                  decoration: InputDecoration(
                                    labelText: 'Confirm Password',
                                    border: const OutlineInputBorder(),
                                    prefixIcon: Image.network(
                                      'https://cdn-icons-png.flaticon.com/512/2889/2889676.png',
                                      height: 20,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Image.network(
                                        _showPassword
                                            ? 'https://cdn-icons-png.flaticon.com/512/709/709612.png'
                                            : 'https://cdn-icons-png.flaticon.com/512/709/709724.png',
                                        height: 22,
                                      ),
                                      onPressed: () => setState(() =>
                                          _showPassword = !_showPassword),
                                    ),
                                  ),
                                  validator: (v) => v!.isEmpty
                                      ? "Please confirm your password"
                                      : null,
                                ),
                                10,
                              ),

                              const SizedBox(height: 25),

                              // ✅ Submit button
                              ElevatedButton.icon(
                                onPressed: _register,
                                icon: Image.network(
                                  'https://cdn-icons-png.flaticon.com/512/845/845646.png',
                                  height: 24,
                                  color: Colors.white,
                                ),
                                label: const Text("Submit for Approval"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(200, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
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
        ),

        // ✅ Loading overlay
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/ojt.png',
                    height: 90,
                  ),
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 4,
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    "Submitting your registration...",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
