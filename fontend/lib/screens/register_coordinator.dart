import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';

class RegisterCoordinator extends StatefulWidget {
  const RegisterCoordinator({super.key});

  @override
  State<RegisterCoordinator> createState() => _RegisterCoordinatorState();
}

class _RegisterCoordinatorState extends State<RegisterCoordinator>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _selectedProgram;
  bool _showPassword = false;
  bool _isLoading = false;
  File? _profileImage;
  Uint8List? _profileImageBytes; // Used for Flutter Web
  final ImagePicker _picker = ImagePicker();

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
    _fullNameController.dispose();
    _emailController.dispose();
    _idController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        setState(() {
          _profileImageBytes = bytes;
          _profileImage = null;
        });
      } else {
        setState(() {
          _profileImage = File(image.path);
          _profileImageBytes = null;
        });
      }
    }
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

    try {
      final fullName = _fullNameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final coordinatorId = _idController.text.trim();

      if (fullName.isEmpty || email.isEmpty || password.isEmpty || _selectedProgram == null) {
        throw Exception('Please fill in all required fields');
      }

      // Convert profile image to base64
      String? profilePhotoBase64;
      if (_profileImageBytes != null) {
        profilePhotoBase64 = base64Encode(_profileImageBytes!);
      } else if (_profileImage != null) {
        final imageBytes = await _profileImage!.readAsBytes();
        profilePhotoBase64 = base64Encode(imageBytes);
      }

      // Store coordinator ID in student_id field (reusing existing field)
      // Store selected program in course field for program-bound approval
      await AuthService.register(
        fullName: fullName,
        email: email,
        password: password,
        role: 'Coordinator',
        studentId: coordinatorId.isNotEmpty ? coordinatorId : null,
        course: _selectedProgram,
        profilePhoto: profilePhotoBase64,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "OJT Coordinator registered successfully! Please wait for admin approval."),
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

                            // Profile Picture
                            GestureDetector(
                              onTap: _pickProfileImage,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeInOut,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.indigo.withOpacity(0.3),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Builder(
                                  builder: (context) {
                                    ImageProvider<Object>? avatarImage;
                                    if (_profileImageBytes != null) {
                                      avatarImage = MemoryImage(_profileImageBytes!);
                                    } else if (_profileImage != null) {
                                      avatarImage = FileImage(_profileImage!);
                                    }

                                    return CircleAvatar(
                                      radius: 55,
                                      backgroundColor: Colors.grey.shade300,
                                      backgroundImage: avatarImage,
                                      child: avatarImage == null
                                          ? Image.network(
                                              'https://cdn-icons-png.flaticon.com/512/2921/2921222.png', // camera icon
                                              height: 40,
                                              color: Colors.indigo,
                                            )
                                          : null,
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              "Tap to upload 2x2 Profile Picture",
                              style: TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                            const SizedBox(height: 20),

                            // 👤 Full Name
                            animatedField(
                              TextFormField(
                                controller: _fullNameController,
                                decoration: const InputDecoration(
                                  labelText: 'Full Name',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) => value!.isEmpty
                                    ? "Please enter your full name"
                                    : null,
                              ),
                              1,
                            ),

                            // 📧 Email
                            animatedField(
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Email Address',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (value!.isEmpty) {
                                    return "Please enter your email";
                                  }
                                  if (!value.contains('@')) {
                                    return "Please enter a valid email";
                                  }
                                  return null;
                                },
                              ),
                              2,
                            ),

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
                              3,
                            ),

                            // 🎓 Assigned Program
                            animatedField(
                              DropdownButtonFormField<String>(
                                value: _selectedProgram,
                                decoration: const InputDecoration(
                                  labelText: 'Assigned Program',
                                  border: OutlineInputBorder(),
                                  hintText: 'Select program to coordinate',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'CS',
                                    child: Text('Computer Science (CS)'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'IS',
                                    child: Text('Information Systems (IS)'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'IT',
                                    child: Text('Information Technology (IT)'),
                                  ),
                                ],
                                onChanged: (value) =>
                                    setState(() => _selectedProgram = value),
                                validator: (v) =>
                                    v == null ? 'Please select your assigned program' : null,
                              ),
                              4,
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
                              4,
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
                              5,
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

