import 'package:flutter/material.dart';

class SupervisorStudentMonitorScreen extends StatefulWidget {
  const SupervisorStudentMonitorScreen({super.key});

  @override
  State<SupervisorStudentMonitorScreen> createState() =>
      _SupervisorStudentMonitorScreenState();
}

class _SupervisorStudentMonitorScreenState
    extends State<SupervisorStudentMonitorScreen> {
  // Sample student data
  final List<Map<String, dynamic>> students = [
    {"name": "Juan Dela Cruz", "completedHours": 300, "requiredHours": 300},
    {"name": "Maria Santos", "completedHours": 150, "requiredHours": 300},
    {"name": "Pedro Reyes", "completedHours": 280, "requiredHours": 300},
  ];

  final Map<String, String> feedbacks = {};
  final Map<String, int> ratings = {};

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
      ),
      body: ListView.builder(
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
