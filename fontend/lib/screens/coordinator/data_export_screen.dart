import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/app_theme.dart';
import '../../services/export_service.dart';

class DataExportScreen extends StatefulWidget {
  const DataExportScreen({super.key});

  @override
  State<DataExportScreen> createState() => _DataExportScreenState();
}

class _DataExportScreenState extends State<DataExportScreen> {
  bool _isExporting = false;
  String? _activeExport;
  DateTimeRange? _attendanceDateRange;
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy');

  Future<void> _export(String type) async {
    setState(() { _isExporting = true; _activeExport = type; });
    try {
      switch (type) {
        case 'attendance':
          await ExportService.exportAttendance(
            startDate: _attendanceDateRange != null
                ? DateFormat('yyyy-MM-dd').format(_attendanceDateRange!.start)
                : null,
            endDate: _attendanceDateRange != null
                ? DateFormat('yyyy-MM-dd').format(_attendanceDateRange!.end)
                : null,
          );
          break;
        case 'students':
          await ExportService.exportStudents();
          break;
        case 'performance':
          await ExportService.exportPerformance();
          break;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Export downloaded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() { _isExporting = false; _activeExport = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Export'),
        backgroundColor: AppTheme.coordinatorPrimary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildExportCard(
            title: 'Attendance Records',
            description: 'Export daily attendance logs with time-in/out, hours worked, and verification status.',
            icon: Icons.fact_check_rounded,
            color: const Color(0xFF1976D2),
            type: 'attendance',
            extra: Column(
              children: [
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2024),
                      lastDate: DateTime.now(),
                      initialDateRange: _attendanceDateRange,
                    );
                    if (picked != null) {
                      setState(() => _attendanceDateRange = picked);
                    }
                  },
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(
                    _attendanceDateRange != null
                        ? '${_dateFormat.format(_attendanceDateRange!.start)} — ${_dateFormat.format(_attendanceDateRange!.end)}'
                        : 'All Dates (tap to filter)',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildExportCard(
            title: 'Student Directory',
            description: 'Export a list of all students with their course, company, contact info, and OJT progress.',
            icon: Icons.people_alt_rounded,
            color: const Color(0xFF388E3C),
            type: 'students',
          ),
          const SizedBox(height: 16),
          _buildExportCard(
            title: 'Performance Summary',
            description: 'Export AI-predicted performance scores, risk levels, grade equivalents, and completion rates.',
            icon: Icons.insights_rounded,
            color: const Color(0xFFE65100),
            type: 'performance',
          ),
        ],
      ),
    );
  }

  Widget _buildExportCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required String type,
    Widget? extra,
  }) {
    final isActive = _activeExport == type;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(description, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
            if (extra != null) extra,
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_isExporting) ? null : () => _export(type),
                icon: isActive
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.download_rounded),
                label: Text(isActive ? 'Exporting...' : 'Download CSV'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

