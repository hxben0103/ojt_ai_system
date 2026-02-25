import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';
import '../models/ojt_record.dart';
import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import '../services/ojt_service.dart';
import '../services/prediction_service.dart';

class CoordinatorStudentMonitor extends StatefulWidget {
  const CoordinatorStudentMonitor({super.key});

  @override
  State<CoordinatorStudentMonitor> createState() => _CoordinatorStudentMonitorState();
}

class StudentMonitorEntry {
  StudentMonitorEntry({
    required this.name,
    required this.studentId,
    required this.hostCompany,
    required this.completedHours,
    required this.requiredHours,
    required this.lastDutyDate,
    required this.onDutyToday,
    this.riskLevel,
    this.riskProbability,
    this.todayAttendanceStatus, // 'Approved', 'Pending', 'Rejected', or null
  });

  final String name;
  final int studentId;
  final String hostCompany;
  final int completedHours;
  final int requiredHours;
  final String lastDutyDate;
  final bool onDutyToday;
  final String? riskLevel;
  final double? riskProbability;
  final String? todayAttendanceStatus; // Status of today's attendance if exists

  int get remainingHours => max(requiredHours - completedHours, 0);
  double get completionPercent =>
      requiredHours <= 0 ? 0 : (completedHours / requiredHours).clamp(0.0, 1.0);
  
  // Helper to get status text for today's attendance
  String get todayStatusText {
    if (onDutyToday) {
      // Student logged attendance - show status
      if (todayAttendanceStatus == 'Approved') {
        return '✅ On Duty Today (Approved)';
      } else if (todayAttendanceStatus == 'Pending') {
        return '⏳ On Duty Today (Pending Approval)';
      } else if (todayAttendanceStatus == 'Rejected') {
        return '❌ On Duty Today (Rejected)';
      } else {
        return '✅ On Duty Today';
      }
    } else {
      return '❌ Not on Duty Today';
    }
  }
  
  // Helper to get status color
  Color get todayStatusColor {
    if (onDutyToday) {
      // Student logged attendance - color based on approval status
      if (todayAttendanceStatus == 'Approved') {
        return Colors.green;
      } else if (todayAttendanceStatus == 'Pending') {
        return Colors.orange;
      } else if (todayAttendanceStatus == 'Rejected') {
        return Colors.red;
      } else {
        return Colors.blue; // Unknown status
      }
    } else {
      return Colors.redAccent; // Not on duty
    }
  }
}

class _CoordinatorStudentMonitorState extends State<CoordinatorStudentMonitor> {
  final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd');

  List<StudentMonitorEntry> _students = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    if (!_isRefreshing) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        setState(() {
          _error = 'User not logged in';
          _isLoading = false;
        });
        return;
      }

      final ojtRecords = await OjtService.getOjtRecords(
        coordinatorId: currentUser.userId,
      );

      if (ojtRecords.isEmpty) {
        setState(() {
          _students = [];
          _isLoading = false;
          _error = null; // Not an error, just no students assigned
        });
        return;
      }

      final entries = await Future.wait(
        ojtRecords.map((record) => _buildStudentEntry(record)),
      );

      setState(() {
        _students = entries.whereType<StudentMonitorEntry>().toList();
        _isLoading = false;
        _isRefreshing = false;
        _error = null;
      });
    } catch (e, stackTrace) {
      setState(() {
        _error = 'Failed to load students: ${e.toString()}';
        _isLoading = false;
        _isRefreshing = false;
        _students = [];
      });
      debugPrint('[CoordinatorStudentMonitor] Error: $e\n$stackTrace');
    }
  }

  Future<StudentMonitorEntry?> _buildStudentEntry(OjtRecord record) async {
    try {
      final summary =
          await AttendanceService.getAttendanceSummary(record.studentId);

      final completedHours = (summary['total_hours_completed'] ?? 0).toInt();
      String? lastDutyDate = summary['last_duty_date'] as String?;

      if (lastDutyDate != null && lastDutyDate != 'N/A') {
        try {
          final parsed = DateTime.parse(lastDutyDate);
          lastDutyDate = _dateFormatter.format(parsed);
        } catch (_) {
          // keep original format
        }
      }

      // Check if student has logged attendance for today (any status)
      // Student is "on duty" if they have logged attendance, regardless of approval status
      bool onDutyToday = false;
      String? todayAttendanceStatus;
      try {
        final todayAttendance = await AttendanceService.getTodayAttendance(record.studentId);
        debugPrint('[CoordinatorStudentMonitor] Student ${record.studentId} today attendance: ${todayAttendance?.status ?? "null"}');
        if (todayAttendance != null) {
          todayAttendanceStatus = todayAttendance.status;
          // Student is "on duty" if they have logged attendance today (Pending, Approved, or Rejected)
          // The status will be shown separately to indicate approval state
          onDutyToday = true;
          debugPrint('[CoordinatorStudentMonitor] Student ${record.studentId} is on duty today with status: $todayAttendanceStatus');
        } else {
          debugPrint('[CoordinatorStudentMonitor] Student ${record.studentId} has no attendance logged for today');
        }
      } catch (e) {
        debugPrint(
            '[CoordinatorStudentMonitor] Error checking today attendance for ${record.studentId}: $e');
        // If check fails, default to false (not on duty)
        onDutyToday = false;
        todayAttendanceStatus = null;
      }

      String? riskLevel;
      double? riskProbability;
      try {
        final prediction =
            await PredictionService.getDailyPrediction(record.studentId);
        final ml = prediction['ai_prediction']?['ml_prediction'];
        if (ml != null) {
          riskLevel = ml['risk_level'] as String?;
          riskProbability = (ml['probability'] as num?)?.toDouble();
        }
      } catch (e) {
        debugPrint(
            '[CoordinatorStudentMonitor] Prediction error for ${record.studentId}: $e');
        riskLevel = 'UNAVAILABLE';
      }

      return StudentMonitorEntry(
        name: record.studentName ?? 'Unknown',
        studentId: record.studentId,
        hostCompany: record.companyName ?? 'N/A',
        completedHours: completedHours,
        requiredHours: record.requiredHours ?? 300,
        lastDutyDate: lastDutyDate ?? 'N/A',
        onDutyToday: onDutyToday, // Only true if approved attendance exists for today
        riskLevel: riskLevel,
        riskProbability: riskProbability,
        todayAttendanceStatus: todayAttendanceStatus, // Status of today's attendance
      );
    } catch (e) {
      debugPrint(
          '[CoordinatorStudentMonitor] Failed to build entry for ${record.studentId}: $e');
      return StudentMonitorEntry(
        name: record.studentName ?? 'Unknown',
        studentId: record.studentId,
        hostCompany: record.companyName ?? 'N/A',
        completedHours: 0,
        requiredHours: record.requiredHours ?? 300,
        lastDutyDate: 'N/A',
        onDutyToday: false,
        riskLevel: null,
        riskProbability: null,
        todayAttendanceStatus: null,
      );
    }
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _isRefreshing = true;
    });
    await _loadStudents();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 72, color: Colors.grey[400]),
          const SizedBox(height: AppTheme.spacing16),
          const Text(
            'No students assigned to you yet.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppTheme.spacing8),
          const Text(
            'Students will appear here once OJT records are created.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacing24),
          ElevatedButton.icon(
            onPressed: _loadStudents,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: AppTheme.primaryButtonStyle(AppTheme.coordinatorPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 72, color: Colors.red[400]),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing16),
            ElevatedButton(
              onPressed: _loadStudents,
              style: AppTheme.primaryButtonStyle(AppTheme.coordinatorPrimary),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(StudentMonitorEntry entry) {
    final initials = entry.name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0])
        .take(2)
        .join();

    final riskColor = _getRiskColor(entry.riskLevel);
    final riskIcon = _getRiskIcon(entry.riskLevel);

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: AppTheme.spacing16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: entry.todayStatusColor,
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacing16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing4),
                  Text('ID: ${entry.studentId}'),
                  Text('Host Company: ${entry.hostCompany}'),
                  const SizedBox(height: AppTheme.spacing8),
                  Text(
                    entry.todayStatusText,
                    style: TextStyle(
                      color: entry.todayStatusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: entry.completionPercent,
                          backgroundColor: Colors.grey[200],
                          color: AppTheme.coordinatorPrimary,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacing8),
                      Text(
                        '${entry.completedHours}/${entry.requiredHours} hrs',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacing6),
                  Text(
                    'Remaining Hours: ${entry.remainingHours}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  Text(
                    'Last Duty Date: ${entry.lastDutyDate}',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  if (entry.riskLevel != null) ...[
                    const SizedBox(height: AppTheme.spacing8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing8,
                        vertical: AppTheme.spacing4,
                      ),
                      decoration: BoxDecoration(
                        color: entry.riskLevel == 'UNAVAILABLE'
                            ? Colors.grey.withOpacity(0.15)
                            : riskColor.withOpacity(0.15),
                        borderRadius:
                            BorderRadius.circular(AppTheme.borderRadiusSmall),
                        border: Border.all(
                          color: entry.riskLevel == 'UNAVAILABLE'
                              ? Colors.grey
                              : riskColor,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            entry.riskLevel == 'UNAVAILABLE'
                                ? Icons.cloud_off_rounded
                                : riskIcon,
                            size: 16,
                            color: entry.riskLevel == 'UNAVAILABLE'
                                ? Colors.grey
                                : riskColor,
                          ),
                          const SizedBox(width: AppTheme.spacing4),
                          Text(
                            entry.riskLevel == 'UNAVAILABLE'
                                ? 'AI Prediction Unavailable'
                                : 'Risk: ${entry.riskLevel}',
                            style: TextStyle(
                              color: entry.riskLevel == 'UNAVAILABLE'
                                  ? Colors.grey
                                  : riskColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (entry.riskProbability != null &&
                              entry.riskLevel != 'UNAVAILABLE') ...[
                            const SizedBox(width: AppTheme.spacing4),
                            Text(
                              '(${(entry.riskProbability! * 100).toStringAsFixed(0)}%)',
                              style: TextStyle(
                                color: riskColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Tasks & Attendance"),
        backgroundColor: AppTheme.coordinatorPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStudents,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _students.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _handleRefresh,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(AppTheme.spacing16),
                        itemCount: _students.length,
                        itemBuilder: (context, index) =>
                            _buildStudentCard(_students[index]),
                      ),
                    ),
    );
  }

  Color _getRiskColor(String? riskLevel) {
    switch (riskLevel?.toUpperCase()) {
      case 'HIGH':
        return Colors.red;
      case 'MEDIUM':
        return Colors.orange;
      case 'LOW':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getRiskIcon(String? riskLevel) {
    switch (riskLevel?.toUpperCase()) {
      case 'HIGH':
        return Icons.warning;
      case 'MEDIUM':
        return Icons.info;
      case 'LOW':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }
}