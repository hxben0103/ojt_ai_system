import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CoordinatorStudentMonitor extends StatelessWidget {
  const CoordinatorStudentMonitor({super.key});

  // Example student data
  final List<Map<String, dynamic>> students = const [
    {
      "name": "Juan Dela Cruz",
      "idNumber": "STU001",
      "department": "IT Department",
      "position": "Student",
      "completedHours": 280,
      "requiredHours": 300,
      "lastDutyDate": "2025-10-28", // YYYY-MM-DD
    },
    {
      "name": "Maria Santos",
      "idNumber": "STU002",
      "department": "Computer Science",
      "position": "Student",
      "completedHours": 150,
      "requiredHours": 300,
      "lastDutyDate": "2025-10-27",
    },
    {
      "name": "Pedro Reyes",
      "idNumber": "STU003",
      "department": "IT Department",
      "position": "Student",
      "completedHours": 300,
      "requiredHours": 300,
      "lastDutyDate": "2025-10-28",
    },
  ];

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text("Student Tasks & Attendance"),
        backgroundColor: Colors.deepPurple,
      ),
      body: ListView.builder(
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
