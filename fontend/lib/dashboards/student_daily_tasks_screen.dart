import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/competency.dart';
import '../models/daily_task.dart';
import '../services/daily_task_service.dart';
import '../services/auth_service.dart';
import '../core/app_theme.dart';
import '../../widgets/restricted_access_screen.dart';
import '../services/ojt_service.dart';
import '../services/prediction_service.dart';

class StudentDailyTasksScreen extends StatefulWidget {
  const StudentDailyTasksScreen({super.key});

  @override
  State<StudentDailyTasksScreen> createState() => _StudentDailyTasksScreenState();
}

class _StudentDailyTasksScreenState extends State<StudentDailyTasksScreen> {
  List<DailyTask> _tasks = [];
  List<Competency> _competencies = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isSuggesting = false;
  String? _error;
  bool _canPerformOjtActions = false;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _taskDescriptionController = TextEditingController();
  final _hoursWorkedController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  Competency? _selectedCompetency;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _taskDescriptionController.dispose();
    _hoursWorkedController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = await AuthService.getCurrentUser();
      if (user?.userId == null) {
        setState(() {
          _error = 'User not logged in';
          _isLoading = false;
        });
        return;
      }

      // ✅ COORDINATOR BYPASS: Allow coordinators to view but not necessarily log
      bool coordinatorBypass = user!.role.toLowerCase().contains('coordinator');

      final results = await Future.wait([
        DailyTaskService.getDailyTasksForStudent(user.userId!),
        DailyTaskService.getCompetencies(program: user.program),
        OjtService.getStudentStatus(user.userId!),
      ]);

      final statusMap = results[2] as Map<String, dynamic>?;

      setState(() {
        _tasks = results[0] as List<DailyTask>;
        _competencies = results[1] as List<Competency>;
        _canPerformOjtActions = coordinatorBypass || (statusMap?['can_perform_ojt_actions'] == true);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _submitTask() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCompetency == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a competency')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = await AuthService.getCurrentUser();
      if (user?.userId == null) {
        throw Exception('User not logged in');
      }

      final hoursWorked = double.tryParse(_hoursWorkedController.text) ?? 0.0;

      await DailyTaskService.createDailyTask(
        studentId: user!.userId!,
        date: _selectedDate,
        taskDescription: _taskDescriptionController.text.trim(),
        hoursWorked: hoursWorked,
        competencyId: _selectedCompetency!.competencyId,
      );

      // Reset form
      _taskDescriptionController.clear();
      _hoursWorkedController.clear();
      _selectedDate = DateTime.now();
      _selectedCompetency = null;

      // Reload tasks
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task submitted and approved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit task: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _suggestCompetency() async {
    final description = _taskDescriptionController.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task description first')),
      );
      return;
    }

    setState(() => _isSuggesting = true);

    try {
      final suggestion = await PredictionService.suggestCompetency(description);
      if (suggestion != null) {
        final matchedCompetency = _competencies.firstWhere(
          (c) => c.title.toLowerCase() == suggestion.toLowerCase(),
          orElse: () => _competencies.firstWhere(
            (c) => c.title.toLowerCase().contains(suggestion.toLowerCase()) || 
                   suggestion.toLowerCase().contains(c.title.toLowerCase()),
            orElse: () => _competencies.first,
          ),
        );

        setState(() {
          _selectedCompetency = matchedCompetency;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('AI suggests: ${matchedCompetency.title}'),
              backgroundColor: AppTheme.studentPrimary,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('AI could not suggest a competency for this task')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSuggesting = false);
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return AppTheme.successColor;
      case 'Rejected':
        return AppTheme.errorColor;
      default:
        return AppTheme.warningColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoading && !_canPerformOjtActions) {
      return const RestrictedAccessScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Tasks & Competencies'),
        backgroundColor: AppTheme.studentPrimary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppTheme.spacing16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Add Task Form
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppTheme.spacing16),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Log New Task',
                                    style: AppTheme.heading3,
                                  ),
                                  const SizedBox(height: AppTheme.spacing16),
                                  
                                  // Date Picker
                                  InkWell(
                                    onTap: _selectDate,
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        labelText: 'Date',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                                        ),
                                        suffixIcon: const Icon(Icons.calendar_today),
                                      ),
                                      child: Text(
                                        DateFormat('yyyy-MM-dd').format(_selectedDate),
                                        style: AppTheme.bodyMedium,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppTheme.spacing12),
                                  
                                  // Competency Dropdown
                                  DropdownButtonFormField<Competency>(
                                    initialValue: _selectedCompetency,
                                    decoration: InputDecoration(
                                      labelText: 'Competency',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                                      ),
                                    ),
                                    items: _competencies.map((competency) {
                                      return DropdownMenuItem(
                                        value: competency,
                                        child: Text('${competency.title} (${competency.pointValue} pts)'),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() => _selectedCompetency = value);
                                    },
                                    validator: (value) {
                                      if (value == null) {
                                        return 'Please select a competency';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: AppTheme.spacing12),
                                  
                                  // Task Description
                                    TextFormField(
                                      controller: _taskDescriptionController,
                                      decoration: InputDecoration(
                                        labelText: 'Task Description',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                                        ),
                                        hintText: 'Describe the task you performed...',
                                        suffixIcon: IconButton(
                                          icon: _isSuggesting 
                                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                            : const Icon(Icons.auto_awesome, color: AppTheme.studentPrimary),
                                          onPressed: _isSuggesting ? null : _suggestCompetency,
                                          tooltip: 'AI Suggest Competency',
                                        ),
                                      ),
                                      maxLines: 3,
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Please enter a task description';
                                        }
                                        return null;
                                      },
                                    ),
                                  const SizedBox(height: AppTheme.spacing12),
                                  
                                  // Hours Worked
                                  TextFormField(
                                    controller: _hoursWorkedController,
                                    decoration: InputDecoration(
                                      labelText: 'Hours Worked',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                                      ),
                                      hintText: 'e.g., 8.0',
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return 'Please enter hours worked';
                                      }
                                      final hours = double.tryParse(value);
                                      if (hours == null || hours <= 0) {
                                        return 'Please enter a valid number of hours';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: AppTheme.spacing16),
                                  
                                  // Submit Button
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _isSubmitting ? null : _submitTask,
                                      style: AppTheme.primaryButtonStyle(AppTheme.studentPrimary),
                                      child: _isSubmitting
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            )
                                          : const Text('Submit Task'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: AppTheme.spacing24),
                        
                        // Tasks List
                        Text(
                          'My Tasks (${_tasks.length})',
                          style: AppTheme.heading3,
                        ),
                        const SizedBox(height: AppTheme.spacing12),
                        
                        if (_tasks.isEmpty)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(AppTheme.spacing24),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.task_alt, size: 64, color: Colors.grey[400]),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No tasks logged yet',
                                      style: AppTheme.bodyLarge.copyWith(color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        else
                          ..._tasks.map((task) => _buildTaskCard(task)),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildTaskCard(DailyTask task) {
    final statusColor = _getStatusColor(task.status);
    
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('MMM dd, yyyy').format(task.date),
                        style: AppTheme.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (task.competencies.isNotEmpty) ...[
                        const SizedBox(height: AppTheme.spacing4),
                        Wrap(
                          spacing: AppTheme.spacing8,
                          children: task.competencies.map((comp) {
                            return Chip(
                              label: Text(
                                comp.title,
                                style: const TextStyle(fontSize: 12),
                              ),
                              backgroundColor: AppTheme.studentPrimary.withOpacity(0.1),
                              padding: EdgeInsets.zero,
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing12,
                    vertical: AppTheme.spacing4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    task.status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing12),
            Text(
              task.taskDescription,
              style: AppTheme.bodyMedium,
            ),
            const SizedBox(height: AppTheme.spacing8),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: AppTheme.spacing4),
                Text(
                  '${task.hoursWorked.toStringAsFixed(1)} hours',
                  style: AppTheme.bodySmall,
                ),
              ],
            ),
            if (task.remarks != null && task.remarks!.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacing8),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.comment, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: AppTheme.spacing8),
                    Expanded(
                      child: Text(
                        'Supervisor: ${task.remarks!}',
                        style: AppTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (task.coordinatorComment != null && task.coordinatorComment!.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacing8),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                  border: Border.all(color: Colors.blue.withOpacity(0.1)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.comment_outlined, size: 16, color: Colors.blue),
                    const SizedBox(width: AppTheme.spacing8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Coordinator: ${task.coordinatorComment!}',
                            style: AppTheme.bodySmall.copyWith(color: Colors.blue[800]),
                          ),
                          if (task.coordinatorCommentAt != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                DateFormat('MMM d').format(task.coordinatorCommentAt!),
                                style: TextStyle(fontSize: 8, color: Colors.blue[400]),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}


