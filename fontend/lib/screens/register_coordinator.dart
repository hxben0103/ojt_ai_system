import 'dart:async';
import 'package:flutter/material.dart';

class RegisterCoordinator extends StatefulWidget {
  const RegisterCoordinator({super.key});

  @override
  State<RegisterCoordinator> createState() => _RegisterCoordinatorState();
}

class _RegisterCoordinatorState extends State<RegisterCoordinator>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _showPassword = false;
  bool _isLoading = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _idController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // 🌀 Submit registration
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match!")),
      );
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            "OJT Coordinator registered successfully! Please wait for admin approval."),
      ),
    );

    Navigator.pop(context);
  }

  // 🧩 Helper widget for fade animation
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
        // 🎨 Background gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3F51B5), Color(0xFF5C6BC0)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),

        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text("OJT Coordinator Registration"),
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: Image.network(
                'https://cdn-icons-png.flaticon.com/512/271/271220.png', // Back arrow icon
                height: 26,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Center(
                  child: Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 10,
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            Image.network(
                              'https://cdn-icons-png.flaticon.com/512/3135/3135715.png', // Coordinator icon
                              height: 80,
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "Coordinator Registration",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo,
                              ),
                            ),
                            const SizedBox(height: 20),

                            // 🔢 ID number
                            animatedField(
                              TextFormField(
                                controller: _idController,
                                decoration: const InputDecoration(
                                  labelText: 'Coordinator ID Number (for login)',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) => value!.isEmpty
                                    ? "Please enter your ID number"
                                    : null,
                              ),
                              1,
                            ),

                            // 🔐 Password
                            animatedField(
                              TextFormField(
                                controller: _passwordController,
                                obscureText: !_showPassword,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    icon: Image.network(
                                      _showPassword
                                          ? 'https://cdn-icons-png.flaticon.com/512/565/565655.png' // eye off
                                          : 'https://cdn-icons-png.flaticon.com/512/565/565654.png', // eye on
                                      height: 22,
                                    ),
                                    onPressed: () => setState(() =>
                                        _showPassword = !_showPassword),
                                  ),
                                ),
                                validator: (value) => value!.isEmpty
                                    ? "Please enter a password"
                                    : null,
                              ),
                              2,
                            ),

                            // 🔐 Confirm Password
                            animatedField(
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: !_showPassword,
                                decoration: InputDecoration(
                                  labelText: 'Confirm Password',
                                  border: const OutlineInputBorder(),
                                  suffixIcon: IconButton(
                                    icon: Image.network(
                                      _showPassword
                                          ? 'https://cdn-icons-png.flaticon.com/512/565/565655.png'
                                          : 'https://cdn-icons-png.flaticon.com/512/565/565654.png',
                                      height: 22,
                                    ),
                                    onPressed: () => setState(() =>
                                        _showPassword = !_showPassword),
                                  ),
                                ),
                                validator: (value) => value!.isEmpty
                                    ? "Please confirm your password"
                                    : null,
                              ),
                              3,
                            ),

                            const SizedBox(height: 25),

                            // ✅ Submit Button
                            AnimatedScale(
                              scale: _isLoading ? 0.95 : 1,
                              duration: const Duration(milliseconds: 300),
                              child: ElevatedButton.icon(
                                onPressed: _isLoading ? null : _register,
                                icon: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Image.network(
                                        'https://cdn-icons-png.flaticon.com/512/845/845646.png', // checkmark icon
                                        height: 22,
                                        color: Colors.white,
                                      ),
                                label: Text(
                                  _isLoading
                                      ? "Submitting..."
                                      : "Submit for Approval",
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.indigo,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(200, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
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

        // 🌀 Loading overlay with logo
        if (_isLoading)
          Container(
            color: Colors.black54,
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
                    "Registering Coordinator...",
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
