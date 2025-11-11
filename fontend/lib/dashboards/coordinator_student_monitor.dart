import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/ojt_service.dart';
import '../services/attendance_service.dart';
import '../services/auth_service.dart';

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

      // Get attendance summary for each student
      final List<Map<String, dynamic>> studentList = [];
      for (final record in ojtRecords) {
        try {
          final summary = await AttendanceService.getSummary(
            studentId: record.studentId,
          );

          int completedHours = 0;
          String? lastDutyDate;
          if (summary.isNotEmpty) {
            completedHours = summary.first['total_hours']?.toInt() ?? 0;
            // Get last attendance date
            final attendanceList = await AttendanceService.getAttendance(
              studentId: record.studentId,
            );
            if (attendanceList.isNotEmpty) {
              attendanceList.sort((a, b) => b.date.compareTo(a.date));
              lastDutyDate = attendanceList.first.date.toIso8601String().split('T')[0];
            }
          }

          studentList.add({
            'name': record.studentName ?? 'Unknown',
            'idNumber': record.studentId.toString(),
            'department': record.companyName ?? 'N/A',
            'position': 'Student',
            'completedHours': completedHours,
            'requiredHours': record.requiredHours ?? 300,
            'lastDutyDate': lastDutyDate ?? 'N/A',
          });
        } catch (e) {
          // If attendance summary fails, still add student with 0 hours
          studentList.add({
            'name': record.studentName ?? 'Unknown',
            'idNumber': record.studentId.toString(),
            'department': record.companyName ?? 'N/A',
            'position': 'Student',
            'completedHours': 0,
            'requiredHours': record.requiredHours ?? 300,
            'lastDutyDate': 'N/A',
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
                      student['name'].split(" ").map((e) => e[0]).take(2).join(),
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
}
