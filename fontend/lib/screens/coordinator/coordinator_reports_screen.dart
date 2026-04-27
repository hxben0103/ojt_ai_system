import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/report_service.dart';
import '../../services/auth_service.dart';
import '../../services/ojt_service.dart';
import '../../models/system_report.dart';
import '../../models/ojt_record.dart';
import '../../models/user.dart';
import '../../utils/report_pdf_generator.dart';
import '../../services/api_service.dart';
import '../../core/config.dart';
import 'package:printing/printing.dart';

class CoordinatorReportsScreen extends StatefulWidget {
  const CoordinatorReportsScreen({super.key});

  @override
  State<CoordinatorReportsScreen> createState() =>
      _CoordinatorReportsScreenState();
}

class _CoordinatorReportsScreenState extends State<CoordinatorReportsScreen> {
  List<SystemReport> _reports = [];
  List<OjtRecord> _students = [];
  bool _isLoading = true;
  String? _errorMessage;
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy');
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _currentUser = await AuthService.getCurrentUser();
      
      // Load both reports and students in parallel
      final results = await Future.wait([
        ReportService.getReports(),
        if (_currentUser?.userId != null)
          OjtService.getOjtRecords(coordinatorId: _currentUser!.userId!)
        else
          Future.value(<OjtRecord>[]),
      ]);

      setState(() {
        _reports = results[0] as List<SystemReport>;
        _students = results[1] as List<OjtRecord>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _generateReport(String reportType, {OjtRecord? student}) async {
    try {
      if (_currentUser?.userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in')),
        );
        return;
      }

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);

      // Add student context if available
      final Map<String, dynamic> content = {
        'title': student != null 
            ? '$reportType - ${student.studentName}' 
            : '$reportType Report',
        'generated_at': now.toIso8601String(),
        'period': '${_dateFormat.format(startOfMonth)} - ${_dateFormat.format(endOfMonth)}',
      };

      if (student != null) {
        content['student_id'] = student.studentId;
        content['student_name'] = student.studentName;
        content['company'] = student.companyName;
        content['supervisor_name'] = student.supervisorName;

        // If it's an OJT Summary, fetch detailed requirement compliance
        if (reportType == 'OJT Summary') {
          try {
            final reqResponse = await ApiService.get('${ApiConfig.ojt}/requirements/${student.studentId}');
            if (reqResponse['requirements'] != null) {
              content['requirements'] = reqResponse['requirements'];
            }
          } catch (e) {
            debugPrint('Failed to fetch requirements for report: $e');
          }
        }
      }

      await ReportService.createReport(
        reportType: reportType,
        generatedBy: _currentUser!.userId!,
        content: content,
        reportPeriodStart: startOfMonth,
        reportPeriodEnd: endOfMonth,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report generated successfully')),
        );
        _loadData(); // Reload both lists
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate report: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Student Reports'),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people_alt_rounded), text: 'Student Portfolio'),
              Tab(icon: Icon(Icons.history_rounded), text: 'Export History'),
            ],
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.assessment_outlined),
              tooltip: 'Generate Class Summary',
              onPressed: () => _generateReport('Coordinator Summary'),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
               onPressed: _loadData,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? _buildErrorView()
                : TabBarView(
                    children: [
                      _buildStudentList(),
                      _buildReportHistory(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: $_errorMessage'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentList() {
    if (_students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('No students assigned to you yet.'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _students.length,
      itemBuilder: (context, index) {
        final student = _students[index];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: Colors.indigo.shade50,
              child: Text(
                student.studentName?[0].toUpperCase() ?? 'S',
                style: TextStyle(color: Colors.indigo.shade700, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              student.studentName ?? 'Unknown Student',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (student.schoolId != null)
                  Text('ID: ${student.schoolId}', 
                    style: TextStyle(color: Colors.indigo.shade600, fontSize: 12, fontWeight: FontWeight.w500)),
                Text(student.companyName ?? 'No company assigned'),
              ],
            ),
            trailing: ElevatedButton(
              onPressed: () => _showGenerateReportDialog(student),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Generate'),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReportHistory() {
    if (_reports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No reports generated yet', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reports.length,
        itemBuilder: (context, index) {
          final report = _reports[index];
          // Try to extract student name from content title
          final title = report.content['title'] ?? report.reportType;
          
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade100),
            ),
            child: ListTile(
              leading: Icon(Icons.picture_as_pdf, color: Colors.red.shade400),
              title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                'Created: ${report.createdAt != null ? _dateFormat.format(report.createdAt!) : "Unknown"}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: () => _confirmDelete(report),
                  ),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
              onTap: () => _showReportDetails(report),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(SystemReport report) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Report'),
        content: const Text('Are you sure you want to permanently delete this report? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        if (report.reportId != null) {
          await ReportService.deleteReport(report.reportId!);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Report deleted successfully')),
            );
          }
          _loadData(); // Refresh list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete report: $e')),
          );
        }
      }
    }
  }

  void _showGenerateReportDialog(OjtRecord student) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.analytics_outlined, color: Colors.indigo),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Generate Report For', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(student.studentName ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            _reportTypeTile(Icons.assessment, 'Attendance Report', () {
              Navigator.pop(context);
              _generateReport('Attendance', student: student);
            }),
            _reportTypeTile(Icons.psychology, 'AI Performance Analysis', () {
              Navigator.pop(context);
              _generateReport('Student Performance', student: student);
            }),
            _reportTypeTile(Icons.business_center, 'OJT Completion Summary', () {
              Navigator.pop(context);
              _generateReport('OJT Summary', student: student);
            }),
            const Divider(),
            _reportTypeTile(Icons.star_outline_rounded, 'Academic Performance Evaluation', () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/coordinator/evaluate');
            }),
          ],
        ),
      ),
    );
  }

  Widget _reportTypeTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey.shade700),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: onTap,
    );
  }

  // Predefined requirement list for UI consistency
  static const List<String> _matrixRequirements = [
    'Application Letter (signed)',
    'Comprehensive Resume (with photo & skills)',
    'Recommendation Letter (from Coordinator)',
    'Draft Memorandum of Agreement (MOA)',
    'Application Letter - Submitted to HTE',
    'Resume - Submitted to HTE',
    'Recommendation Letter - Submitted to HTE',
    'Draft MOA - Submitted to HTE',
    'Accepted Recommendation Letter (from HTE)',
    'Accepted or Revised MOA (from HTE)',
    'Final MOA (5 copies)',
    'Proof of Notarization Payment',
    'Parent\'s Consent and Waiver',
    'Medical Certificate (Fit to Work)',
    'Pregnancy Test (for female students)',
    'OB-GYN Certificate (if applicable)',
    'Chest X-ray',
    'Hepatitis B Test',
    'Blood Type Test',
    'Urinalysis',
    'Complete Blood Count (CBC)'
  ];

  void _showReportDetails(SystemReport report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(report.reportType),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (report.generatedByName != null)
                Text('Generated by: ${report.generatedByName}'),
              if (report.createdAt != null)
                Text('Created: ${_dateFormat.format(report.createdAt!)}'),
              if (report.reportPeriodStart != null &&
                  report.reportPeriodEnd != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Period: ${_dateFormat.format(report.reportPeriodStart!)} - ${_dateFormat.format(report.reportPeriodEnd!)}',
                ),
              ],
              if (report.status != null) ...[
                const SizedBox(height: 8),
                Text('Status: ${report.status}'),
              ],
              const SizedBox(height: 16),
              const Text(
                'Report Content:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if ((report.reportType == 'Coordinator Summary' || report.reportType == 'Admin Master Summary') && report.content['students'] != null)
                _buildSummaryTable(report.content['students'] as List<dynamic>)
              else ...[
                if (report.content['requirements'] != null) ...[
                  const Text('Requirement Compliance:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: (report.content['requirements'] as List).length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final req = report.content['requirements'][index];
                        final bool isCompleted = req['status'] == 'Completed';
                        return ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          leading: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: isCompleted ? Colors.indigo.shade600 : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isCompleted ? Colors.indigo.shade600 : Colors.grey.shade400,
                                width: 1.5,
                              ),
                            ),
                            child: isCompleted
                                ? const Icon(Icons.check, color: Colors.white, size: 14)
                                : null,
                          ),
                          title: Text(
                            req['requirement_name'] ?? 'Unknown',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                              color: isCompleted ? Colors.black87 : Colors.black45,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                    Container(
                      padding: const EdgeInsets.all(12),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _formatPreviewContent(report.content ?? {}),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Requirement Legend:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: List.generate(_matrixRequirements.length, (index) => 
                        SizedBox(
                          width: 150,
                          child: Text(
                            'R${index + 1}: ${_matrixRequirements[index]}',
                            style: const TextStyle(fontSize: 9, color: Colors.black54),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        actions: [
          ElevatedButton.icon(
            onPressed: () => _printReport(report),
            icon: const Icon(Icons.print, size: 18),
            label: const Text('Print PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _printReport(SystemReport report) async {
    try {
      final pdfBytes = await ReportPdfGenerator.generateReportPdf(report);
      await Printing.layoutPdf(
        onLayout: (format) => pdfBytes,
        name: '${report.reportType}_${DateTime.now().millisecondsSinceEpoch}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to print report: $e')),
        );
      }
    }
  }

  String _formatPreviewContent(Map<String, dynamic> content) {
    final Map<String, dynamic> filtered = Map.from(content)
      ..remove('title')
      ..remove('generated_at')
      ..remove('period')
      ..remove('student_id')
      ..remove('student_name')
      ..remove('company')
      ..remove('requirements');
    
    if (filtered.isEmpty) {
      return 'No additional details available for this report.';
    }

    final StringBuffer buffer = StringBuffer();
    filtered.forEach((key, value) {
      buffer.writeln('${key.replaceAll('_', ' ').toUpperCase()}: $value');
    });
    return buffer.toString().trim();
  }

  Widget _buildSummaryTable(List<dynamic> students) {
    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
            columnSpacing: 15,
            headingRowHeight: 40,
            dataRowHeight: 40,
            headingRowColor: WidgetStateProperty.all(Colors.indigo.shade50),
            columns: [
              const DataColumn(label: Text('School ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              const DataColumn(label: Text('Student Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              const DataColumn(label: Text('Company', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              const DataColumn(label: Text('Performance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              const DataColumn(label: Text('Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              const DataColumn(label: Text('Completed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              // Matrix Columns
              ...List.generate(_matrixRequirements.length, (index) => 
                DataColumn(label: Text('R${index + 1}', 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.indigo)))
              ),
            ],
            rows: students.map((s) {
              final progressValue = s['progress'];
              final status = s['compliance_status']?.toString() ?? '0/21';
              final matrix = s['requirements_matrix'] as Map<String, dynamic>? ?? {};
              
              String progress = '0';
              if (progressValue is num) {
                progress = progressValue.toStringAsFixed(0);
              } else if (progressValue is String) {
                progress = double.tryParse(progressValue)?.toStringAsFixed(0) ?? '0';
              }

              return DataRow(cells: [
                DataCell(Text(s['school_id']?.toString() ?? 'N/A', style: const TextStyle(fontSize: 11))),
                DataCell(Text(s['student_name']?.toString() ?? 'Unknown', style: const TextStyle(fontSize: 11))),
                DataCell(Text(s['company']?.toString() ?? 'N/A', style: const TextStyle(fontSize: 11))),
                DataCell(Text(s['performance']?.toString() ?? 'N/A', style: const TextStyle(fontSize: 11))),
                DataCell(Text('$progress%', style: const TextStyle(fontSize: 11))),
                DataCell(
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      status.replaceFirst(' Completed', ''),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.indigo.shade900),
                    ),
                  ),
                ),
                // Matrix Cells
                ..._matrixRequirements.map((req) {
                  final isDone = matrix[req] == 'Completed';
                  return DataCell(
                    Center(
                      child: Icon(
                        isDone ? Icons.check_box : Icons.check_box_outline_blank,
                        size: 16,
                        color: isDone ? Colors.indigo : Colors.grey.shade400,
                      ),
                    ),
                  );
                }),
              ]);
            }).toList(),
          ),
        ),
      );
    },
  ),
),
);
}
}


