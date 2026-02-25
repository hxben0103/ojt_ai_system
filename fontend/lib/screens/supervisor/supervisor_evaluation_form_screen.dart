import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/evaluation_service.dart';
import '../../services/ojt_service.dart';
import '../../services/auth_service.dart';
import '../../models/ojt_record.dart';

class SupervisorEvaluationFormScreen extends StatefulWidget {
  const SupervisorEvaluationFormScreen({super.key});

  @override
  State<SupervisorEvaluationFormScreen> createState() =>
      _SupervisorEvaluationFormScreenState();
}

class _SupervisorEvaluationFormScreenState
    extends State<SupervisorEvaluationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  List<OjtRecord> _students = [];
  OjtRecord? _selectedStudent;
  bool _isLoading = false;
  bool _isLoadingStudents = true;

  // Evaluation criteria
  final Map<String, TextEditingController> _criteriaControllers = {
    'Punctuality': TextEditingController(),
    'Work Quality': TextEditingController(),
    'Communication': TextEditingController(),
    'Teamwork': TextEditingController(),
    'Initiative': TextEditingController(),
    'Professionalism': TextEditingController(),
  };

  final TextEditingController _feedbackController = TextEditingController();
  DateTime? _periodStart;
  DateTime? _periodEnd;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    for (var controller in _criteriaControllers.values) {
      controller.dispose();
    }
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser?.userId == null) return;

      final records = await OjtService.getOjtRecords(
          supervisorId: currentUser!.userId);
      setState(() {
        _students = records;
        _isLoadingStudents = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingStudents = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading students: $e')),
        );
      }
    }
  }

  Future<void> _submitEvaluation() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a student')),
      );
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      final currentUser = await AuthService.getCurrentUser();
      if (currentUser?.userId == null) {
        throw Exception('User not logged in');
      }

      final criteria = <String, dynamic>{};
      double totalScore = 0;
      int count = 0;

      for (var entry in _criteriaControllers.entries) {
        final score = double.tryParse(entry.value.text);
        if (score != null && score >= 0 && score <= 100) {
          criteria[entry.key] = score;
          totalScore += score;
          count++;
        }
      }

      final avgScore = count > 0 ? totalScore / count : null;

      await EvaluationService.createEvaluation(
        studentId: _selectedStudent!.studentId,
        supervisorId: currentUser!.userId!,
        criteria: criteria,
        totalScore: avgScore,
        feedback: _feedbackController.text.isNotEmpty
            ? _feedbackController.text
            : null,
        evaluationPeriodStart: _periodStart,
        evaluationPeriodEnd: _periodEnd,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evaluation submitted successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit evaluation: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Evaluation'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isLoadingStudents
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Student Selection
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Select Student',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<OjtRecord>(
                            value: _selectedStudent,
                            decoration: const InputDecoration(
                              labelText: 'Student',
                              border: OutlineInputBorder(),
                            ),
                            items: _students.map((student) {
                              return DropdownMenuItem(
                                value: student,
                                child: Text(student.studentName ?? 'Unknown'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedStudent = value;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Please select a student';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Evaluation Period
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Evaluation Period',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ListTile(
                                  title: Text(_periodStart != null
                                      ? DateFormat('MMM d, yyyy')
                                          .format(_periodStart!)
                                      : 'Start Date'),
                                  trailing: const Icon(Icons.calendar_today),
                                  onTap: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now(),
                                    );
                                    if (date != null) {
                                      setState(() {
                                        _periodStart = date;
                                      });
                                    }
                                  },
                                ),
                              ),
                              Expanded(
                                child: ListTile(
                                  title: Text(_periodEnd != null
                                      ? DateFormat('MMM d, yyyy')
                                          .format(_periodEnd!)
                                      : 'End Date'),
                                  trailing: const Icon(Icons.calendar_today),
                                  onTap: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: _periodStart ?? DateTime.now(),
                                      firstDate: _periodStart ?? DateTime(2020),
                                      lastDate: DateTime.now(),
                                    );
                                    if (date != null) {
                                      setState(() {
                                        _periodEnd = date;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Evaluation Criteria
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Evaluation Criteria (0-100)',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._criteriaControllers.entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: TextFormField(
                                controller: entry.value,
                                decoration: InputDecoration(
                                  labelText: entry.key,
                                  border: const OutlineInputBorder(),
                                  suffixText: '/100',
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a score';
                                  }
                                  final score = double.tryParse(value);
                                  if (score == null || score < 0 || score > 100) {
                                    return 'Score must be between 0 and 100';
                                  }
                                  return null;
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Feedback
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Feedback',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _feedbackController,
                            decoration: const InputDecoration(
                              labelText: 'Additional Comments',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 5,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitEvaluation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Submit Evaluation',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

