import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../widgets/restricted_access_screen.dart';
import '../../services/ojt_service.dart';
import '../../models/narrative_report.dart';
import '../../core/app_theme.dart';

class StudentProgressReportScreen extends StatefulWidget {
  const StudentProgressReportScreen({super.key});

  @override
  State<StudentProgressReportScreen> createState() =>
      _StudentProgressReportScreenState();
}

class _StudentProgressReportScreenState
    extends State<StudentProgressReportScreen> {
  bool _isLoading = true;
  bool _isUploading = false;
  bool _canPerformOjtActions = false;
  List<NarrativeReport> _history = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    try {
      await _checkOjtStatus();
      await _fetchHistory();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkOjtStatus() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user?.userId != null) {
        final status = await OjtService.getStudentStatus(user!.userId!);
        if (mounted) {
          setState(() {
            _canPerformOjtActions = status['can_perform_ojt_actions'] == true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking OJT status: $e');
    }
  }

  Future<void> _fetchHistory() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user?.userId != null) {
        final reports = await OjtService.getNarrativeReports(studentId: user!.userId!);
        if (mounted) {
          setState(() {
            _history = reports;
            _errorMessage = null;
          });
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to load report history');
    }
  }

  Future<void> _viewReport(NarrativeReport report) async {
    if (report.reportId == null) return;
    
    final token = await AuthService.getToken();
    final url = Uri.parse(OjtService.getNarrativeReportUrl(
      report.reportId!,
      token: token,
    ));
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open report viewer')),
        );
      }
    }
  }

  void _showUploadDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _NarrativeUploadSheet(
        onSuccess: () {
          Navigator.pop(context);
          _fetchHistory();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_canPerformOjtActions) {
      return const RestrictedAccessScreen();
    }

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: Text(
          'My Narrative Reports',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : _history.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final report = _history[index];
                    return _buildReportCard(report);
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showUploadDialog,
        backgroundColor: AppTheme.studentPrimary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Report', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No reports submitted yet',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _showUploadDialog,
            child: const Text('Start your first report'),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(NarrativeReport report) {
    Color statusColor = Colors.orange;
    if (report.status == 'Approved') statusColor = Colors.green;
    if (report.status == 'Rejected') statusColor = Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    report.title,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    report.status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              report.description ?? 'No description provided.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(
                  report.reportDate != null
                      ? DateFormat('MMM d, yyyy').format(report.reportDate!)
                      : 'N/A',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
                const Spacer(),
                if (report.rating != null && report.rating! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Score: ${report.rating}%',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _viewReport(report),
                  icon: const Icon(Icons.open_in_new, size: 14),
                  label: const Text('View File'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.studentPrimary,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            if (report.feedback != null && report.feedback!.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                'Feedback:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade700),
              ),
              const SizedBox(height: 4),
              Text(
                report.feedback!,
                style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade500, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NarrativeUploadSheet extends StatefulWidget {
  final VoidCallback onSuccess;

  const _NarrativeUploadSheet({required this.onSuccess});

  @override
  State<_NarrativeUploadSheet> createState() => _NarrativeUploadSheetState();
}

class _NarrativeUploadSheetState extends State<_NarrativeUploadSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  File? _selectedFile;
  Uint8List? _selectedFileBytes;
  String? _fileName;
  bool _isUploading = false;

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );

      if (result != null) {
        if (kIsWeb) {
          setState(() {
            _selectedFileBytes = result.files.single.bytes;
            _fileName = result.files.single.name;
          });
        } else {
          setState(() {
            _selectedFile = File(result.files.single.path!);
            _fileName = result.files.single.name;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file')),
      );
      return;
    }

    setState(() => _isUploading = true);
    try {
      final user = await AuthService.getCurrentUser();
      await OjtService.uploadNarrativeReport(
        studentId: user!.userId!,
        title: _titleController.text,
        description: _descriptionController.text,
        file: kIsWeb ? _selectedFileBytes : _selectedFile,
        fileName: _fileName!,
      );
      widget.onSuccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Submit Narrative Report',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Report Title',
                    hintText: 'e.g. Week 1 Narrative',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  validator: (v) => v?.isEmpty == true ? 'Title is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Key Learnings/Description',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  validator: (v) => v?.isEmpty == true ? 'Description is required' : null,
                ),
                const SizedBox(height: 20),
                InkWell(
                  onTap: _pickFile,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _fileName != null ? Colors.green.shade50 : Colors.blueGrey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _fileName != null ? Colors.green.shade200 : Colors.blueGrey.shade100,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _fileName != null ? Icons.check_circle : Icons.upload_file,
                          color: _fileName != null ? Colors.green : Colors.blueGrey,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            _fileName ?? 'Select PDF or Document',
                            style: TextStyle(
                              color: _fileName != null ? Colors.green.shade700 : Colors.blueGrey.shade600,
                              fontWeight: _fileName != null ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (_fileName != null)
                          const Icon(Icons.refresh, size: 16, color: Colors.green),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.studentPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isUploading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Submit Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


