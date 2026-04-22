import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../models/narrative_report.dart';
import '../../services/ojt_service.dart';
import '../../core/app_theme.dart';

class CoordinatorStudentReportsScreen extends StatefulWidget {
  final int studentId;
  final String studentName;
  final List<NarrativeReport> reports;

  const CoordinatorStudentReportsScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.reports,
  });

  @override
  State<CoordinatorStudentReportsScreen> createState() => _CoordinatorStudentReportsScreenState();
}

class _CoordinatorStudentReportsScreenState extends State<CoordinatorStudentReportsScreen> {
  late List<NarrativeReport> _reports;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _reports = List.from(widget.reports);
    // Sort: Pending first, then by date
    _reports.sort((a, b) {
      if (a.status == 'Pending' && b.status != 'Pending') return -1;
      if (a.status != 'Pending' && b.status == 'Pending') return 1;
      return b.createdAt?.compareTo(a.createdAt ?? DateTime.now()) ?? 0;
    });
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

  void _showReviewDialog(NarrativeReport report) {
    final TextEditingController ratingController = TextEditingController(
      text: report.rating != null && report.rating! > 0 ? report.rating?.toString() : '',
    );
    final TextEditingController feedbackController = TextEditingController(
      text: report.feedback ?? '',
    );
    String selectedStatus = report.status == 'Pending' ? 'Approved' : report.status;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Review Report',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.coordinatorPrimary),
                ),
                const SizedBox(height: 16),
                const Text('Set Status', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: ['Pending', 'Approved', 'Rejected'].map((status) {
                    final isSelected = selectedStatus == status;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(status, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : Colors.black87)),
                        selected: isSelected,
                        selectedColor: status == 'Approved' ? Colors.green : (status == 'Rejected' ? Colors.red : Colors.orange),
                        onSelected: (val) {
                          if (val) setModalState(() => selectedStatus = status);
                        },
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
                const Text('Rating (0-100)', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: ratingController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'e.g. 95',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.star_rounded, color: Colors.amber),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Coordinator Feedback', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: feedbackController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Add comments for the student...',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final int rating = int.tryParse(ratingController.text) ?? 0;
                if (rating < 0 || rating > 100) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid rating (0-100)')),
                  );
                  return;
                }

                try {
                  final updatedReport = await OjtService.reviewNarrativeReport(
                    reportId: report.reportId!,
                    status: selectedStatus,
                    rating: rating,
                    feedback: feedbackController.text,
                  );
                  
                  if (mounted) {
                    setState(() {
                      final index = _reports.indexWhere((r) => r.reportId == report.reportId);
                      if (index != -1) _reports[index] = updatedReport;
                      _hasChanges = true;
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Report updated successfully')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.coordinatorPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Save Review'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _hasChanges);
        return false;
      },
      child: Scaffold(
        backgroundColor: AppTheme.surfaceColor,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.studentName,
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Text(
                'Narrative Submissions',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.black87,
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _reports.length,
          itemBuilder: (context, index) {
            final report = _reports[index];
            return _buildReportItem(report);
          },
        ),
      ),
    );
  }

  Widget _buildReportItem(NarrativeReport report) {
    Color statusColor = Colors.orange;
    if (report.status == 'Approved') statusColor = Colors.green;
    if (report.status == 'Rejected') statusColor = Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: report.status == 'Pending' 
            ? Border.all(color: Colors.orange.withOpacity(0.3), width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
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
                        style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold),
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
                        style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  report.description ?? 'No description provided',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 6),
                    Text(
                      report.reportDate != null ? DateFormat('MMM d, yyyy').format(report.reportDate!) : 'No Date',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                    ),
                    const Spacer(),
                    if (report.rating != null && report.rating! > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Score: ${report.rating}%',
                          style: TextStyle(color: Colors.indigo.shade700, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                TextButton.icon(
                  onPressed: () => _viewReport(report),
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: const Text('View File'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.coordinatorPrimary),
                ),
                TextButton.icon(
                  onPressed: () => _showReviewDialog(report),
                  icon: const Icon(Icons.rate_review_outlined, size: 18),
                  label: Text(report.status == 'Pending' ? 'Rate Now' : 'Edit Rating'),
                  style: TextButton.styleFrom(
                    foregroundColor: report.status == 'Pending' ? Colors.orange.shade800 : Colors.blueGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
