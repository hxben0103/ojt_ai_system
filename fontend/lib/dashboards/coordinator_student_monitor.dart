import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/ojt_service.dart';
import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import '../services/prediction_service.dart';

class CoordinatorStudentMonitor extends StatefulWidget {
  const CoordinatorStudentMonitor({super.key});

  @override
  State<CoordinatorStudentMonitor> createState() => _CoordinatorStudentMonitorState();
}

class _CoordinatorStudentMonitorState extends State<CoordinatorStudentMonitor> {
  List<Map<String, dynamic>> students = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Get current user to find coordinator_id
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
        setState(() {
          _error = 'User not logged in';
          _isLoading = false;
        });
        return;
      }

      // Get OJT records for this coordinator
      final ojtRecords = await OjtService.getOjtRecords(
        coordinatorId: currentUser.userId,
      );

      // Get attendance summary for each student using the new optimized endpoint
      final List<Map<String, dynamic>> studentList = [];
      for (final record in ojtRecords) {
        try {
          // Use the new getAttendanceSummary method which returns all needed data in one call
          final summary = await AttendanceService.getAttendanceSummary(record.studentId);

          int completedHours = (summary['total_hours_completed'] ?? 0).toInt();
          String? lastDutyDate = summary['last_duty_date'] as String?;

          // Get daily risk prediction
          Map<String, dynamic>? predictionData;
          String? riskLevel;
          double? riskProbability;
          try {
            predictionData = await PredictionService.getDailyPrediction(record.studentId);
            if (predictionData['ai_prediction'] != null &&
                predictionData['ai_prediction']['prediction'] != null) {
              riskLevel = predictionData['ai_prediction']['prediction']['risk_level'] as String?;
              riskProbability = (predictionData['ai_prediction']['prediction']['probability'] as num?)?.toDouble();
            }
          } catch (e) {
            print('Error loading prediction for student ${record.studentId}: $e');
            // Continue without prediction data
          }

          studentList.add({
            'name': record.studentName ?? 'Unknown',
            'idNumber': record.studentId.toString(),
            'department': record.companyName ?? 'N/A',
            'position': 'Student',
            'completedHours': completedHours,
            'requiredHours': record.requiredHours ?? 300,
            'lastDutyDate': lastDutyDate ?? 'N/A',
            'riskLevel': riskLevel,
            'riskProbability': riskProbability,
          });
        } catch (e) {
          // If attendance summary fails, still add student with 0 hours
          print('Error loading attendance for student ${record.studentId}: $e');
          studentList.add({
            'name': record.studentName ?? 'Unknown',
            'idNumber': record.studentId.toString(),
            'department': record.companyName ?? 'N/A',
            'position': 'Student',
            'completedHours': 0,
            'requiredHours': record.requiredHours ?? 300,
            'lastDutyDate': 'N/A',
            'riskLevel': null,
            'riskProbability': null,
          });
        }
      }

      setState(() {
        students = studentList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load students: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Tasks & Attendance"),
        backgroundColor: Colors.deepPurple,
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
                        onPressed: _loadStudents,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : students.isEmpty
                  ? const Center(
                      child: Text('No students assigned to you yet.'),
                    )
                  : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: students.length,
        itemBuilder: (context, index) {
          final student = students[index];
          final remainingHours =
              (student['requiredHours'] - student['completedHours']).clamp(0, student['requiredHours']);
          final onDutyToday = student['lastDutyDate'] == today;

          return Card(
            elevation: 4,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // CircleAvatar with initials
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: onDutyToday ? Colors.green : Colors.red,
                    child: Text(
                      (student['name'] as String).split(" ").where((e) => e.isNotEmpty).map((e) => e[0]).take(2).join(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Student info and status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(student['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text("ID: ${student['idNumber']}"),
                        Text("Department: ${student['department']}"),
                        Text("Position: ${student['position']}"),
                        const SizedBox(height: 8),
                        Text("Remaining Hours: $remainingHours"),
                        const SizedBox(height: 4),
                        Text(
                          onDutyToday ? "✅ On Duty Today" : "❌ Not on Duty Today",
                          style: TextStyle(
                            color: onDutyToday ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // Risk Level Badge
                        if (student['riskLevel'] != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getRiskColor(student['riskLevel']).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getRiskColor(student['riskLevel']),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getRiskIcon(student['riskLevel']),
                                  size: 16,
                                  color: _getRiskColor(student['riskLevel']),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Risk: ${student['riskLevel']}',
                                  style: TextStyle(
                                    color: _getRiskColor(student['riskLevel']),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                if (student['riskProbability'] != null) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    '(${(student['riskProbability'] * 100).toStringAsFixed(0)}%)',
                                    style: TextStyle(
                                      color: _getRiskColor(student['riskLevel']),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        // Progress bar
                        LinearProgressIndicator(
                          value: student['completedHours'] / student['requiredHours'],
                          backgroundColor: Colors.grey[300],
                          color: Colors.deepPurple,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
