import 'package:flutter/material.dart';
import '../services/ojt_service.dart';
import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import '../models/user.dart';

class SupervisorStudentMonitorScreen extends StatefulWidget {
  const SupervisorStudentMonitorScreen({super.key});

  @override
  State<SupervisorStudentMonitorScreen> createState() =>
      _SupervisorStudentMonitorScreenState();
}

class _SupervisorStudentMonitorScreenState
    extends State<SupervisorStudentMonitorScreen> {
  List<Map<String, dynamic>> students = [];
  bool _isLoading = true;
  String? _error;
  final Map<String, String> feedbacks = {};
  final Map<String, int> ratings = {};

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

      // Get current user to find supervisor_id
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser == null) {
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

      // Get attendance summary for each student
      final List<Map<String, dynamic>> studentList = [];
      for (final record in ojtRecords) {
        try {
          final summary = await AttendanceService.getSummary(
            studentId: record.studentId,
          );

          int completedHours = 0;
          if (summary.isNotEmpty) {
            completedHours = summary.first['total_hours']?.toInt() ?? 0;
          }

          studentList.add({
            'studentId': record.studentId,
            'name': record.studentName ?? 'Unknown',
            'completedHours': completedHours,
            'requiredHours': record.requiredHours ?? 300,
          });
        } catch (e) {
          // If attendance summary fails, still add student with 0 hours
          studentList.add({
            'studentId': record.studentId,
            'name': record.studentName ?? 'Unknown',
            'completedHours': 0,
            'requiredHours': record.requiredHours ?? 300,
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

  void _openFeedbackDialog(Map<String, dynamic> student) {
    // ✅ Check if student has completed OJT hours
    if (student['completedHours'] < student['requiredHours']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "${student['name']} has not completed required OJT hours yet."),
          backgroundColor: Colors.red,
        ),
      );
      return; // Do not open feedback dialog
    }

    final TextEditingController feedbackController = TextEditingController();
    int selectedRating = ratings[student['name']] ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Feedback & Rating - ${student['name']}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: feedbackController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: "Write feedback here...",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < selectedRating
                        ? Icons.star
                        : Icons.star_border_outlined,
                    color: Colors.orange,
                  ),
                  onPressed: () {
                    setState(() {
                      selectedRating = index + 1;
                    });
                    Navigator.pop(ctx);
                    _openFeedbackDialog(student);
                  },
                );
              }),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel")),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              onPressed: () {
                setState(() {
                  feedbacks[student['name']] = feedbackController.text.trim();
                  ratings[student['name']] = selectedRating;
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(
                          "Feedback & rating submitted for ${student['name']}")),
                );
              },
              child: const Text("Submit"))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Monitor Student OJT Progress"),
        backgroundColor: Colors.teal,
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
          final progress = student['completedHours'] / student['requiredHours'];
          final isCompleted = student['completedHours'] >= student['requiredHours'];

          return Card(
            elevation: 4,
            margin: const EdgeInsets.only(bottom: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(
                student['name'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      "OJT Hours: ${student['completedHours']} / ${student['requiredHours']}"),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: progress > 1 ? 1 : progress,
                    backgroundColor: Colors.grey[300],
                    color: isCompleted ? Colors.green : Colors.teal,
                  ),
                  if (feedbacks.containsKey(student['name']))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                          "Feedback: ${feedbacks[student['name']]}\nRating: ${ratings[student['name']]}/5"),
                    ),
                ],
              ),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCompleted ? Colors.teal : Colors.grey,
                ),
                child: const Text("Feedback"),
                onPressed: () => _openFeedbackDialog(student),
              ),
            ),
          );
        },
      ),
    );
  }
}
