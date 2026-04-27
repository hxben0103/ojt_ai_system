import 'package:flutter/material.dart';
import '../../models/system_report.dart';
import '../../services/report_service.dart';
import '../../utils/report_pdf_generator.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  bool _isLoading = true;
  List<SystemReport> _reports = [];
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _loadAllReports();
  }

  Future<void> _loadAllReports() async {
    try {
      setState(() => _isLoading = true);
      final reports = await ReportService.getReports(); // Admins see all reports by default in backend
      setState(() {
        _reports = reports;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load reports: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateMasterSummary() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Generate Master Summary"),
        content: const Text("This will aggregate performance data for ALL active students across all coordinators. Proceed?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            child: const Text("Generate"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        setState(() => _isLoading = true);
        await ReportService.createReport(
          reportType: 'Admin Master Summary',
          content: {}, // Backend will auto-generate
        );
        await _loadAllReports();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Master Summary generated successfully!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Generation failed: $e')),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('System-Wide Reports'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.assessment_rounded),
            tooltip: 'Generate Master Summary',
            onPressed: _isLoading ? null : _generateMasterSummary,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllReports,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
              ? _buildEmptyState()
              : _buildReportsList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.description_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('No system reports found', style: TextStyle(color: Colors.grey, fontSize: 18)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _generateMasterSummary,
            icon: const Icon(Icons.add),
            label: const Text('Generate First Master Summary'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reports.length,
      itemBuilder: (context, index) {
        final report = _reports[index];
        final isSummary = report.reportType.contains('Summary');
        
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              backgroundColor: isSummary ? Colors.indigo.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
              child: Icon(
                isSummary ? Icons.summarize_rounded : Icons.person_search_rounded,
                color: isSummary ? Colors.indigo : Colors.orange,
              ),
            ),
            title: Text(
              report.content['title'] ?? report.reportType,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('By: ${report.generatedByName ?? "System"}'),
                Text(_dateFormat.format(report.createdAt ?? DateTime.now())),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  onPressed: () => _confirmDelete(report),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => _showReportDetails(report),
          ),
        );
      },
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
          _loadAllReports(); // Refresh list
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

  void _showReportDetails(SystemReport report) {
    final students = report.content['students'] as List<dynamic>?;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(report.content['title'] ?? report.reportType),
        content: SizedBox(
          width: double.maxFinite,
          child: students != null
              ? _buildSummaryTable(students)
              : SingleChildScrollView(
                  child: Text(report.content.toString()),
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

  Widget _buildSummaryTable(List<dynamic> students) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        headingRowHeight: 40,
        columns: const [
          DataColumn(label: Text('School ID', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Student Name', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Company', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Performance', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Progress %', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: students.map((s) {
          final progressValue = s['progress'];
          String progress = '0';
          
          if (progressValue is num) {
            progress = progressValue.toStringAsFixed(0);
          } else if (progressValue is String) {
            progress = double.tryParse(progressValue)?.toStringAsFixed(0) ?? '0';
          }

          return DataRow(cells: [
            DataCell(Text(s['school_id']?.toString() ?? 'N/A')),
            DataCell(Text(s['student_name']?.toString() ?? 'Unknown')),
            DataCell(Text(s['company']?.toString() ?? 'N/A')),
            DataCell(Text(s['performance']?.toString() ?? 'N/A')),
            DataCell(Text('$progress%')),
          ]);
        }).toList(),
      ),
    );
  }
}

