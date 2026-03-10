import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/evaluation_service.dart';
import '../../services/ojt_service.dart';
import '../../models/ojt_record.dart';
import '../../services/attendance_service.dart';
import '../../services/auth_service.dart';

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
  Map<int, double> _studentProgressMap = {};
  bool _isEvaluating = false;

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
          
      final progressMap = <int, double>{};
      await Future.wait(records.map((r) async {
         try {
            final summary = await AttendanceService.getAttendanceSummary(r.studentId);
            final completed = (summary['total_hours_completed'] as num?)?.toDouble() ?? 0.0;
            progressMap[r.studentId] = completed;
         } catch(e) {
            progressMap[r.studentId] = 0.0;
         }
      }));

      if (mounted) {
        setState(() {
          _students = records;
          _studentProgressMap = progressMap;
          _isLoadingStudents = false;
        });
      }
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
        setState(() {
          _isEvaluating = false;
          _selectedStudent = null;
        });
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

  Widget _buildStudentListView() {
    if (_students.isEmpty) {
      return const Center(child: Text('No students assigned.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _students.length,
      itemBuilder: (context, index) {
        final student = _students[index];
        final completed = _studentProgressMap[student.studentId] ?? 0.0;
        final req = student.requiredHours ?? 300;
        final isReady = completed >= req;
        final progressPct = req > 0 ? (completed / req).clamp(0.0, 1.0) : 0.0;
        final barColor = isReady ? Colors.green : Colors.orange;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        student.studentName ?? 'Unknown',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (isReady)
                      const Icon(Icons.check_circle, color: Colors.green)
                    else
                      const Icon(Icons.pending_actions, color: Colors.orange),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('OJT Completion', style: TextStyle(fontSize: 14, color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                    Text('${completed.toInt()} / $req hrs', style: TextStyle(fontSize: 14, color: barColor, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressPct,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isReady ? () {
                      setState(() {
                        _selectedStudent = student;
                        _isEvaluating = true;
                      });
                    } : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isReady ? Colors.teal : Colors.grey.shade300,
                      foregroundColor: isReady ? Colors.white : Colors.grey.shade600,
                    ),
                    child: Text(isReady ? 'Evaluate Student' : 'Not Yet Completed'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEvaluating ? 'Evaluate ${_selectedStudent?.studentName ?? ''}' : 'Student Progress'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        leading: _isEvaluating
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _isEvaluating = false;
                    _selectedStudent = null;
                  });
                },
              )
            : const BackButton(),
      ),
      body: _isLoadingStudents
          ? const Center(child: CircularProgressIndicator())
          : !_isEvaluating
              ? _buildStudentListView()
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Selected Student Info Header
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedStudent?.studentName ?? 'Unknown',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              const Text('OJT Progress: 100% Completed', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500)),
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

