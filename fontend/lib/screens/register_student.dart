import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class RegisterStudent extends StatefulWidget {
  const RegisterStudent({super.key});

  @override
  State<RegisterStudent> createState() => _RegisterStudentState();
}

class _RegisterStudentState extends State<RegisterStudent>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  // Controllers
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

  // ✅ Generate Full Name automatically
  void _generateFullName() {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    setState(() {
      _fullNameController.text = "$first $last".trim();
    });
  }

  // ✅ Pick profile picture
  Future<void> _pickProfileImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
      });
    }
  }

  // ✅ Submit form
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match!")),
      );
      return;
    }

    if (_profileImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please upload your 2x2 profile picture.")),
      );
      return;
    }

    // ✅ Show loading overlay
    setState(() => _isLoading = true);

    await Future.delayed(const Duration(seconds: 3)); // simulate server delay

    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            "Registration submitted successfully! Please wait for OJT Coordinator approval."),
      ),
    );

    Navigator.pop(context);
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

  // ✅ Helper Widget: Animated Fade-in Field
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

                              // ✅ Profile picture
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
                                  child: CircleAvatar(
                                    radius: 55,
                                    backgroundColor: Colors.grey.shade300,
                                    backgroundImage: _profileImage != null
                                        ? FileImage(_profileImage!)
                                        : null,
                                    child: _profileImage == null
                                        ? const Icon(Icons.camera_alt,
                                            size: 40, color: Colors.white)
                                        : null,
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

                              // ✅ Form fields
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
                                  validator: (v) =>
                                      v == null ? "Please select your gender" : null,
                                ),
                                5,
                              ),
                              animatedField(
                                DropdownButtonFormField<String>(
                                  value: _selectedCourse,
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
                                      onPressed: () => setState(
                                          () => _showPassword = !_showPassword),
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
                                      icon: Icon(_showPassword
                                          ? Icons.visibility_off
                                          : Icons.visibility),
                                      onPressed: () => setState(
                                          () => _showPassword = !_showPassword),
                                    ),
                                  ),
                                ),
                                13,
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

        // ✅ Loading Spinner Overlay with School Logo
        if (_isLoading)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🔷 Replace with your school logo in assets
                  Image.asset(
                    'assets/images/ojt.png', // <-- make sure logo exists
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
