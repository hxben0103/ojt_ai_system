import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';

class RegisterStudent extends StatefulWidget {
  const RegisterStudent({super.key});

  @override
  State<RegisterStudent> createState() => _RegisterStudentState();
}

class _RegisterStudentState extends State<RegisterStudent>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _ojtHoursController = TextEditingController(text: "300");
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _selectedGender;
  String? _selectedCourse;
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
    _animController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
  }

  void _generateFullName() {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    setState(() {
      _fullNameController.text = "$first $last".trim();
    });
  }

  Future<void> _pickProfileImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      if (kIsWeb) {
        // On web, use bytes instead of File to avoid unsupported _Namespace operation
        final bytes = await image.readAsBytes();
        setState(() {
          _profileImageBytes = bytes;
          _profileImage = null;
        });
      } else {
        // Mobile/desktop can safely use File from dart:io
      setState(() {
        _profileImage = File(image.path);
          _profileImageBytes = null;
      });
      }
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match!")),
      );
      return;
    }

    if (_profileImage == null && _profileImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please upload your 2x2 profile picture.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final fullName = _fullNameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final studentId = _idController.text.trim();
      final course = _selectedCourse ?? '';
      final age = _ageController.text.trim().isNotEmpty 
          ? int.tryParse(_ageController.text.trim()) 
          : null;
      final gender = _selectedGender ?? '';
      final contactNumber = _contactController.text.trim();
      final address = _addressController.text.trim();
      final requiredHours = _ojtHoursController.text.trim().isNotEmpty
          ? int.tryParse(_ojtHoursController.text.trim())
          : 300;

      if (fullName.isEmpty || email.isEmpty || password.isEmpty) {
        throw Exception('Please fill in all required fields');
      }

      // Convert profile image to base64 for database storage
      List<int>? imageBytes;
      if (_profileImageBytes != null) {
        imageBytes = _profileImageBytes;
      } else if (_profileImage != null) {
        imageBytes = await _profileImage!.readAsBytes();
      }

      // NOTE: Photos are stored as base64 text in the database.
      // Supabase Storage bucket upload has been removed for simplicity.
      String? finalProfilePhoto = imageBytes != null ? base64Encode(imageBytes) : null;

      await AuthService.register(
        fullName: fullName,
        email: email,
        password: password,
        role: 'Student',
        studentId: studentId.isNotEmpty ? studentId : null,
        course: course.isNotEmpty ? course : null,
        age: age,
        gender: gender.isNotEmpty ? gender : null,
        contactNumber: contactNumber.isNotEmpty ? contactNumber : null,
        address: address.isNotEmpty ? address : null,
        requiredHours: requiredHours,
        profilePhoto: finalProfilePhoto,
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
    _firstNameController.dispose();
    _lastNameController.dispose();
    _fullNameController.dispose();
    _ageController.dispose();
    _ojtHoursController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _idController.dispose();
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
            backgroundColor: Colors.indigo,
            title: const Text("Student Registration"),
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
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
                              const SizedBox(height: 10),
                              const Text(
                                "Student Registration",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo,
                                ),
                              ),
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
                                            ? const Icon(Icons.camera_alt, size: 40, color: Colors.indigo)
                                            : null,
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                "Tap to upload 2x2 Profile Picture",
                                style:
                                    TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                              const SizedBox(height: 20),

                              // Form Fields
                              animatedField(
                                TextFormField(
                                  controller: _firstNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'First Name',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => _generateFullName(),
                                  validator: (v) => v!.isEmpty
                                      ? "Please enter your first name"
                                      : null,
                                ),
                                1,
                              ),
                              animatedField(
                                TextFormField(
                                  controller: _lastNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Last Name',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (_) => _generateFullName(),
                                  validator: (v) => v!.isEmpty
                                      ? "Please enter your last name"
                                      : null,
                                ),
                                2,
                              ),
                              animatedField(
                                TextFormField(
                                  controller: _fullNameController,
                                  readOnly: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Full Name (auto)',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                3,
                              ),
                              animatedField(
                                TextFormField(
                                  controller: _ageController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Age',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (v) =>
                                      v!.isEmpty ? "Please enter your age" : null,
                                ),
                                4,
                              ),
                              animatedField(
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedGender,
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
                                  validator: (v) =>
                                      v == null ? "Please select your gender" : null,
                                ),
                                5,
                              ),
                              animatedField(
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedCourse,
                                  decoration: const InputDecoration(
                                    labelText: "Course",
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                        value: "CS",
                                        child: Text("Computer Science (CS)")),
                                    DropdownMenuItem(
                                        value: "IS",
                                        child:
                                            Text("Information Systems (IS)")),
                                    DropdownMenuItem(
                                        value: "IT",
                                        child: Text(
                                            "Information Technology (IT)")),
                                  ],
                                  onChanged: (value) =>
                                      setState(() => _selectedCourse = value),
                                  validator: (v) =>
                                      v == null ? "Please select your course" : null,
                                ),
                                6,
                              ),
                              animatedField(
                                TextFormField(
                                  controller: _ojtHoursController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'OJT Hours Required',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                7,
                              ),
                              animatedField(
                                TextFormField(
                                  controller: _contactController,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    labelText: 'Contact Number',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                8,
                              ),
                              animatedField(
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'Email Address',
                                    border: OutlineInputBorder(),
                                  ),
                                  // E5 FIX: Added inline email validation
                                  validator: (v) {
                                    if (v == null || v.isEmpty) return "Please enter your email";
                                    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
                                      return "Please enter a valid email address";
                                    }
                                    return null;
                                  },
                                ),
                                9,
                              ),
                              animatedField(
                                TextFormField(
                                  controller: _addressController,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                    labelText: 'Home Address',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                10,
                              ),
                              animatedField(
                                TextFormField(
                                  controller: _idController,
                                  decoration: const InputDecoration(
                                    labelText: 'Student ID Number (for login)',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                11,
                              ),

                              // Password fields
                              // E12 FIX: Replaced Image.network CDN icons with Flutter Icons
                              animatedField(
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: !_showPassword,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    border: const OutlineInputBorder(),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _showPassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: Colors.indigo,
                                      ),
                                      onPressed: () => setState(() =>
                                          _showPassword = !_showPassword),
                                    ),
                                  ),
                                ),
                                12,
                              ),
                              animatedField(
                                TextFormField(
                                  controller: _confirmPasswordController,
                                  obscureText: !_showPassword,
                                  decoration: InputDecoration(
                                    labelText: 'Confirm Password',
                                    border: const OutlineInputBorder(),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _showPassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: Colors.indigo,
                                      ),
                                      onPressed: () => setState(() =>
                                          _showPassword = !_showPassword),
                                    ),
                                  ),
                                ),
                                13,
                              ),
                              const SizedBox(height: 25),

                              // Submit button
                              ElevatedButton.icon(
                                onPressed: _register,
                                icon: const Icon(Icons.check_circle, color: Colors.white),
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

        // Loading Overlay
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

