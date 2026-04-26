import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import '../services/ojt_service.dart';
import '../models/attendance.dart';
import '../models/ojt_record.dart';
import '../widgets/geofence_status_badge.dart';
import '../widgets/spoof_warning_banner.dart';

class SupervisorAttendanceVerificationScreen extends StatefulWidget {
  const SupervisorAttendanceVerificationScreen({super.key});

  @override
  State<SupervisorAttendanceVerificationScreen> createState() =>
      _SupervisorAttendanceVerificationScreenState();
}

class _SupervisorAttendanceVerificationScreenState
    extends State<SupervisorAttendanceVerificationScreen> {
  List<Attendance> _attendanceRecords = [];
  List<OjtRecord> _ojtRecords = [];
  bool _isLoading = true;
  String? _error;
  int? _selectedStudentId;
  String? _selectedDate;
  DateTime? _filterDate;
  /// Filter by verification_status (FLAGGED for coordinator review)
  String? _filterVerificationStatus;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null || currentUser.userId == null) {
        setState(() {
          _error = 'User not logged in';
          _isLoading = false;
        });
        return;
      }

      // Get OJT records for this supervisor
      final ojtRecords = await OjtService.getOjtRecords(
        supervisorId: currentUser.userId,
      );

      setState(() {
        _ojtRecords = ojtRecords;
      });

      // Load attendance for all students
      await _loadAttendance();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAttendance() async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser?.userId == null) return;

      final List<Attendance> allAttendance = [];

      for (final record in _ojtRecords) {
        try {
          final attendance = await AttendanceService.getAttendance(
            studentId: record.studentId,
            date: _selectedDate,
          );
          allAttendance.addAll(attendance);
        } catch (_) {
          // Skip if error for one student
        }
      }

      // Filter by selected student if any
      var filteredAttendance = _selectedStudentId != null
          ? allAttendance
              .where((a) => a.studentId == _selectedStudentId)
              .toList()
          : allAttendance;

      // Filter by verification_status (e.g. FLAGGED for coordinator review)
      if (_filterVerificationStatus != null &&
          _filterVerificationStatus!.isNotEmpty) {
        filteredAttendance = filteredAttendance
            .where((a) => a.verificationStatus == _filterVerificationStatus)
            .toList();
      }

      // Sort by date descending
      filteredAttendance.sort((a, b) => b.date.compareTo(a.date));

      setState(() {
        _attendanceRecords = filteredAttendance;
      });
    } catch (e) {
      print('Error loading attendance: $e');
    }
  }

  Future<void> _verifyAttendance(Attendance attendance) async {
    if (attendance.attendanceId == null) return;

    try {
      await AttendanceService.verifyAttendance(attendance.attendanceId!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Attendance for ${attendance.studentName ?? "Student"} on ${DateFormat('MMM dd, yyyy').format(attendance.date)} verified successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
        await _loadAttendance();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to verify attendance: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _unverifyAttendance(Attendance attendance) async {
    if (attendance.attendanceId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Verification'),
        content: Text(
          'Are you sure you want to remove verification for ${attendance.studentName ?? "this student"}\'s attendance on ${DateFormat('MMM dd, yyyy').format(attendance.date)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await AttendanceService.unverifyAttendance(attendance.attendanceId!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification removed successfully'),
            backgroundColor: Colors.orange,
          ),
        );
        await _loadAttendance();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove verification: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _filterDate = picked;
        _selectedDate = DateFormat('yyyy-MM-dd').format(picked);
      });
      await _loadAttendance();
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedStudentId = null;
      _selectedDate = null;
      _filterDate = null;
    });
    _loadAttendance();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Student Attendance'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Filters
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.grey[100],
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int?>(
                                  value: _selectedStudentId,
                                  decoration: const InputDecoration(
                                    labelText: 'Filter by Student',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  items: [
                                    const DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text('All Students'),
                                    ),
                                    ..._ojtRecords.map((record) =>
                                        DropdownMenuItem<int?>(
                                          value: record.studentId,
                                          child: Text(record.studentName ??
                                              'Unknown Student'),
                                        )),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedStudentId = value;
                                    });
                                    _loadAttendance();
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              DropdownButtonFormField<String?>(
                                value: _filterVerificationStatus,
                                decoration: const InputDecoration(
                                  labelText: 'Verification status',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('All'),
                                  ),
                                  DropdownMenuItem<String?>(
                                    value: 'FLAGGED',
                                    child: Text('FLAGGED'),
                                  ),
                                  DropdownMenuItem<String?>(
                                    value: 'AUTO_VERIFIED',
                                    child: Text('AUTO_VERIFIED'),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(() {
                                    _filterVerificationStatus = value;
                                  });
                                  _loadAttendance();
                                },
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: _selectDate,
                                icon: const Icon(Icons.calendar_today),
                                label: Text(
                                  _filterDate != null
                                      ? DateFormat('MMM dd').format(_filterDate!)
                                      : 'Select Date',
                                ),
                              ),
                            ],
                          ),
                          if (_selectedStudentId != null || _selectedDate != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Filters: ${_selectedStudentId != null ? "Student" : ""} ${_selectedDate != null ? "Date" : ""}',
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _clearFilters,
                                    child: const Text('Clear Filters'),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Summary
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.teal[50],
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSummaryCard(
                            'Total Records',
                            '${_attendanceRecords.length}',
                            Colors.blue,
                          ),
                          _buildSummaryCard(
                            'Flagged Activity',
                            '${_attendanceRecords.where((a) => a.verificationStatus == 'FLAGGED').length}',
                            Colors.red,
                          ),
                        ],
                      ),
                    ),
                    // Attendance List
                    Expanded(
                      child: _attendanceRecords.isEmpty
                          ? const Center(
                              child: Text('No attendance records found'),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadAttendance,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _attendanceRecords.length,
                                itemBuilder: (context, index) {
                                  final attendance = _attendanceRecords[index];
                                  return _buildAttendanceCard(attendance);
                                },
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceCard(Attendance attendance) {
    final isVerified = attendance.verified;
    final dateStr = DateFormat('MMM dd, yyyy').format(attendance.date);
    final verifiedDateStr = attendance.verifiedAt != null
        ? DateFormat('MMM dd, yyyy HH:mm').format(attendance.verifiedAt!)
        : null;

    List<String> trustReasons = [];
    if (attendance.trustFlags != null &&
        attendance.trustFlags!.isNotEmpty) {
      try {
        final decoded = jsonDecode(attendance.trustFlags!);
        if (decoded is List) {
          trustReasons =
              decoded.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
        } else if (decoded is String) {
          trustReasons = [decoded];
        }
      } catch (_) {
        trustReasons = [attendance.trustFlags!];
      }
    }

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isVerified ? Colors.green : Colors.grey[300]!,
          width: isVerified ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        attendance.studentName ?? 'Unknown Student',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (attendance.verificationStatus == 'FLAGGED')
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.report_problem_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'FLAGGED',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Time details
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                if (attendance.morningIn != null)
                  _buildTimeChip('AM In', attendance.morningIn!),
                if (attendance.morningOut != null)
                  _buildTimeChip('AM Out', attendance.morningOut!),
                if (attendance.afternoonIn != null)
                  _buildTimeChip('PM In', attendance.afternoonIn!),
                if (attendance.afternoonOut != null)
                  _buildTimeChip('PM Out', attendance.afternoonOut!),
                if (attendance.overtimeIn != null)
                  _buildTimeChip('OT In', attendance.overtimeIn!),
                if (attendance.overtimeOut != null)
                  _buildTimeChip('OT Out', attendance.overtimeOut!),
              ],
            ),
            if (attendance.deductionMinutes != null && attendance.deductionMinutes! > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.timer_off, size: 16, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    'Late Deduction: ${attendance.deductionMinutes} mins',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
            if (attendance.totalHours != null) ...[
              const SizedBox(height: 8),
              Text(
                'Credited Hours: ${attendance.totalHours!.toStringAsFixed(1)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
            ],
            // Evidence: verification_status, location, trust, photo (coordinator/admin)
            if (attendance.verificationStatus != null ||
                attendance.insideGeofence != null ||
                attendance.trustScore != null ||
                attendance.checkinLat != null ||
                attendance.attendanceImage != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              Text(
                'Evidence',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (attendance.verificationStatus != null)
                    Chip(
                      label: Text(
                        attendance.verificationStatus!,
                        style: const TextStyle(fontSize: 11),
                      ),
                      backgroundColor: attendance.verificationStatus == 'FLAGGED'
                          ? Colors.orange[100]
                          : Colors.green[100],
                    ),
                  if (attendance.insideGeofence != null)
                    GeofenceStatusBadge(
                      inside: attendance.insideGeofence!,
                    ),
                  if (attendance.trustScore != null)
                    Chip(
                      label: Text(
                        'Trust: ${attendance.trustScore}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  if (attendance.checkinLat != null &&
                      attendance.checkinLng != null)
                    Chip(
                      label: Text(
                        'In: ${attendance.checkinLat!.toStringAsFixed(4)}, ${attendance.checkinLng!.toStringAsFixed(4)}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  if (attendance.checkoutLat != null &&
                      attendance.checkoutLng != null)
                    Chip(
                      label: Text(
                        'Out: ${attendance.checkoutLat!.toStringAsFixed(4)}, ${attendance.checkoutLng!.toStringAsFixed(4)}',
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  if (attendance.attendanceImage != null &&
                      attendance.attendanceImage!.isNotEmpty)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        base64Decode(attendance.attendanceImage!),
                        height: 80,
                        width: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(
                          height: 80,
                          width: 80,
                          child: Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                ],
              ),
              if (trustReasons.isNotEmpty) ...[
                const SizedBox(height: 8),
                SpoofWarningBanner(
                  reasons: trustReasons,
                  trustScore: attendance.trustScore ?? 0,
                ),
              ],
            ],
            if (isVerified && verifiedDateStr != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.verified_user, size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    'Verified by ${attendance.verifiedByName ?? "Supervisor"} on $verifiedDateStr',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            // Action buttons removed (Auto-Approved model)
          ],
        ),
      ),
    );
  }

  Widget _buildTimeChip(String label, String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Text(
        '$label: $time',
        style: TextStyle(
          fontSize: 12,
          color: Colors.blue[900],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}


