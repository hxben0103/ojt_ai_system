import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/report_service.dart';
import '../../services/auth_service.dart';
import '../../models/system_report.dart';

class CoordinatorReportsScreen extends StatefulWidget {
  const CoordinatorReportsScreen({super.key});

  @override
  State<CoordinatorReportsScreen> createState() =>
      _CoordinatorReportsScreenState();
}

class _CoordinatorReportsScreenState extends State<CoordinatorReportsScreen> {
  List<SystemReport> _reports = [];
  bool _isLoading = true;
  String? _errorMessage;
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final reports = await ReportService.getReports();
      setState(() {
        _reports = reports;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _generateReport(String reportType) async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser?.userId == null) {
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

      final report = await ReportService.createReport(
        reportType: reportType,
        generatedBy: currentUser!.userId!,
        content: {
          'title': '$reportType Report',
          'generated_at': now.toIso8601String(),
          'period': '${_dateFormat.format(startOfMonth)} - ${_dateFormat.format(endOfMonth)}',
        },
        reportPeriodStart: startOfMonth,
        reportPeriodEnd: endOfMonth,
      );

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report generated successfully')),
        );
        _loadReports();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showGenerateReportDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: $_errorMessage'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadReports,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _reports.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.description_outlined,
                              size: 64, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            'No reports generated yet',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _showGenerateReportDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Generate Report'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadReports,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _reports.length,
                        itemBuilder: (context, index) {
                          final report = _reports[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    Colors.deepPurple.withOpacity(0.1),
                                child: const Icon(Icons.description,
                                    color: Colors.deepPurple),
                              ),
                              title: Text(
                                report.reportType,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (report.generatedByName != null)
                                    Text('Generated by: ${report.generatedByName}'),
                                  if (report.createdAt != null)
                                    Text(
                                      'Created: ${_dateFormat.format(report.createdAt!)}',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  if (report.reportPeriodStart != null &&
                                      report.reportPeriodEnd != null)
                                    Text(
                                      'Period: ${_dateFormat.format(report.reportPeriodStart!)} - ${_dateFormat.format(report.reportPeriodEnd!)}',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                ],
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _showReportDetails(report),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  void _showGenerateReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.assessment),
              title: const Text('Attendance Report'),
              onTap: () {
                Navigator.pop(context);
                _generateReport('Attendance');
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Student Performance Report'),
              onTap: () {
                Navigator.pop(context);
                _generateReport('Student Performance');
              },
            ),
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('OJT Summary Report'),
              onTap: () {
                Navigator.pop(context);
                _generateReport('OJT Summary');
              },
            ),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Overall Statistics Report'),
              onTap: () {
                Navigator.pop(context);
                _generateReport('Overall Statistics');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  report.content.toString(),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

