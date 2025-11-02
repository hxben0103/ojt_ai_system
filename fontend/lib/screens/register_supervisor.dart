import 'package:flutter/material.dart';
import 'dart:async';

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

    // Simulate a registration delay
    await Future.delayed(const Duration(seconds: 3));

    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Registration submitted successfully! Please wait for OJT Coordinator approval.",
        ),
      ),
    );

    Navigator.pop(context);
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
              icon: const Icon(Icons.arrow_back),
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
                              const Icon(Icons.engineering,
                                  size: 90, color: Colors.indigo),
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

                              // ✅ Fields start here
                              animatedField(
                                TextFormField(
                                  controller: _fullNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Full Name',
                                    border: OutlineInputBorder(),
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
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Supervisor ID Number (for login)',
                                    border: OutlineInputBorder(),
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
                                  decoration: const InputDecoration(
                                    labelText: 'Email Address',
                                    border: OutlineInputBorder(),
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
                                  decoration: const InputDecoration(
                                    labelText: "Gender",
                                    border: OutlineInputBorder(),
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
                                  decoration: const InputDecoration(
                                    labelText: 'Phone Number',
                                    border: OutlineInputBorder(),
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
                                  decoration: const InputDecoration(
                                    labelText: 'Office / Department',
                                    border: OutlineInputBorder(),
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
                                  decoration: const InputDecoration(
                                    labelText: 'Position / Role',
                                    border: OutlineInputBorder(),
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
                                  decoration: const InputDecoration(
                                    labelText: 'Office Location / Address',
                                    border: OutlineInputBorder(),
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
                                    suffixIcon: IconButton(
                                      icon: Icon(_showPassword
                                          ? Icons.visibility_off
                                          : Icons.visibility),
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
                                    suffixIcon: IconButton(
                                      icon: Icon(_showPassword
                                          ? Icons.visibility_off
                                          : Icons.visibility),
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
                                icon: const Icon(Icons.check_circle_outline),
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

        // ✅ Loading overlay with logo
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/ojt.png', // Replace with your logo
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
