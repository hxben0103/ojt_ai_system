import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../core/app_theme.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../core/config.dart';

class StudentChecklistScreen extends StatefulWidget {
  const StudentChecklistScreen({super.key});

  @override
  State<StudentChecklistScreen> createState() => _StudentChecklistScreenState();
}

class _StudentChecklistScreenState extends State<StudentChecklistScreen> {
  // Track requirements from backend
  List<dynamic> _requirements = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchRequirements();
  }

  Future<void> _fetchRequirements() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user?.userId == null) throw Exception("User not authenticated");

      final response = await ApiService.get('${ApiConfig.ojt}/requirements/${user!.userId}');
      if (response['requirements'] != null) {
        setState(() {
          _requirements = response['requirements'];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // --- File Upload Function ---
  Future<void> _uploadFile(String label) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = result.files.single;
        final fileName = file.name;

        final user = await AuthService.getCurrentUser();
        if (user?.userId == null) return;

        // Update backend
        await ApiService.post('${ApiConfig.ojt}/requirements/${user!.userId}/update', {
          'requirement_name': label,
          'status': 'Completed',
          'file_path': fileName,
        });

        // Refresh list
        await _fetchRequirements();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: AppTheme.spacing8),
                  Expanded(
                    child: Text(
                      "'$fileName' uploaded successfully!",
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppTheme.successColor,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.white),
                  SizedBox(width: AppTheme.spacing8),
                  Text("No file selected."),
                ],
              ),
              backgroundColor: AppTheme.warningColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: AppTheme.spacing8),
                Expanded(
                  child: Text("File upload failed: $e"),
                ),
              ],
            ),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // --- Upload item widget ---
  Widget _buildUploadItem(String label, {IconData? icon}) {
    // Find requirement in the list fetched from backend
    final req = _requirements.firstWhere(
      (r) => r['requirement_name'] == label,
      orElse: () => null,
    );

    final bool isCompleted = req != null && req['status'] == 'Completed';
    final String? fileName = req != null ? req['file_path'] : null;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppTheme.spacing8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
        side: BorderSide(
          color: isCompleted
              ? AppTheme.successColor.withOpacity(0.2)
              : Colors.grey.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
        onTap: () => _uploadFile(label),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing12),
          child: Row(
            children: [
              // Checkmark or Blank box
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isCompleted ? AppTheme.successColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isCompleted ? AppTheme.successColor : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
              const SizedBox(width: AppTheme.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: isCompleted ? FontWeight.w600 : FontWeight.w400,
                        color: isCompleted ? Colors.black87 : Colors.black54,
                      ),
                    ),
                    if (isCompleted && fileName != null) ...[
                      const SizedBox(height: AppTheme.spacing2),
                      Text(
                        fileName,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.successColor.withOpacity(0.8),
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              if (!isCompleted)
                Icon(
                  Icons.upload_file,
                  color: AppTheme.studentPrimary.withOpacity(0.5),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Step Header Widget ---
  Widget _buildStepHeader(String stepNumber, String title, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(
        top: AppTheme.spacing24,
        bottom: AppTheme.spacing12,
      ),
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: AppTheme.studentPrimary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
        border: Border.all(
          color: AppTheme.studentPrimary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.studentPrimary,
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stepNumber,
                  style: AppTheme.bodySmall.copyWith(
                    color: AppTheme.studentPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  title,
                  style: AppTheme.heading3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- OJT Checklist Section ---
  Widget _buildChecklistCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
      ),
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.studentPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                  ),
                  child: Icon(
                    Icons.checklist,
                    color: AppTheme.studentPrimary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "OJT APPLICATION CHECKLIST",
                        style: AppTheme.heading2,
                      ),
                      const SizedBox(height: AppTheme.spacing4),
                      Text(
                        "Upload required documents for your OJT application",
                        style: AppTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing8),

            // Progress indicator
            if (_requirements.any((r) => r['status'] == 'Completed')) ...[
              const SizedBox(height: AppTheme.spacing16),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing12),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.trending_up,
                      color: AppTheme.successColor,
                      size: 20,
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                    Text(
                      "${_requirements.where((r) => r['status'] == 'Completed').length} document(s) completed",
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.successColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Step 2
            _buildStepHeader(
              "STEP 2",
              "Seek Your OJT Coordinator",
              Icons.person_search,
            ),
            _buildUploadItem("Application Letter (signed)", icon: Icons.description),
            _buildUploadItem("Comprehensive Resume (with photo & skills)", icon: Icons.badge),
            _buildUploadItem("Recommendation Letter (from Coordinator)", icon: Icons.recommend),
            _buildUploadItem("Draft Memorandum of Agreement (MOA)", icon: Icons.gavel),

            // Step 3
            _buildStepHeader(
              "STEP 3",
              "Apply to the Host Training Establishment",
              Icons.business_center,
            ),
            _buildUploadItem("Application Letter - Submitted to HTE", icon: Icons.send),
            _buildUploadItem("Resume - Submitted to HTE", icon: Icons.send),
            _buildUploadItem("Recommendation Letter - Submitted to HTE", icon: Icons.send),
            _buildUploadItem("Draft MOA - Submitted to HTE", icon: Icons.send),
            _buildUploadItem("Accepted Recommendation Letter (from HTE)", icon: Icons.check_circle_outline),
            _buildUploadItem("Accepted or Revised MOA (from HTE)", icon: Icons.check_circle_outline),

            // Step 4
            _buildStepHeader(
              "STEP 4",
              "Preparation of Final MOA",
              Icons.assignment,
            ),
            _buildUploadItem("Final MOA (5 copies)", icon: Icons.copy),
            _buildUploadItem("Proof of Notarization Payment", icon: Icons.payment),

            // Step 5
            _buildStepHeader(
              "STEP 5",
              "Secure Required Documents",
              Icons.medical_services,
            ),
            _buildUploadItem("Parent's Consent and Waiver", icon: Icons.people),
            _buildUploadItem("Medical Certificate (Fit to Work)", icon: Icons.medical_services),
            _buildUploadItem("Pregnancy Test (for female students)", icon: Icons.person),
            _buildUploadItem("OB-GYN Certificate (if applicable)", icon: Icons.local_hospital),
            _buildUploadItem("Chest X-ray", icon: Icons.image_search),
            _buildUploadItem("Hepatitis B Test", icon: Icons.science),
            _buildUploadItem("Blood Type Test", icon: Icons.water_drop),
            _buildUploadItem("Urinalysis", icon: Icons.science_outlined),
            _buildUploadItem("Complete Blood Count (CBC)", icon: Icons.analytics),

            // Note section
            const SizedBox(height: AppTheme.spacing24),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                border: Border.all(
                  color: AppTheme.warningColor.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppTheme.warningColor,
                    size: 24,
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Expanded(
                    child: Text(
                      "NOTE: Ensure your HTE indicates acceptance on the Recommendation Letter before proceeding to MOA signing.",
                      style: AppTheme.bodyMedium.copyWith(
                        fontStyle: FontStyle.italic,
                        color: AppTheme.warningColor.withOpacity(0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),
          ],
        ),
      ),
    );
  }

  // --- MAIN BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.checklist_rtl,
              color: Colors.white,
              size: 26,
            ),
            const SizedBox(width: AppTheme.spacing8),
            const Text("OJT Application Checklist"),
          ],
        ),
        backgroundColor: AppTheme.studentPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text("Error: $_errorMessage"),
                      ElevatedButton(
                        onPressed: _fetchRequirements,
                        child: const Text("Retry"),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
                  child: _buildChecklistCard(),
                ),
    );
  }
}

