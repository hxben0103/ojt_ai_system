import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/daily_task.dart';
import '../services/daily_task_service.dart';
import '../services/auth_service.dart';
import '../core/app_theme.dart';

class SupervisorDailyTasksReviewScreen extends StatefulWidget {
  const SupervisorDailyTasksReviewScreen({super.key});

  @override
  State<SupervisorDailyTasksReviewScreen> createState() => _SupervisorDailyTasksReviewScreenState();
}

class _SupervisorDailyTasksReviewScreenState extends State<SupervisorDailyTasksReviewScreen> {
  List<DailyTask> _pendingTasks = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPendingTasks();
  }

  Future<void> _loadPendingTasks() async {
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

      final tasks = await DailyTaskService.getPendingTasksForSupervisor(user!.userId!);
      setState(() {
        _pendingTasks = tasks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load tasks: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateTaskStatus(DailyTask task, String status, {String? remarks}) async {
    try {
      await DailyTaskService.updateTaskStatus(
        taskId: task.taskId,
        status: status,
        remarks: remarks,
      );

      // Remove from pending list
      setState(() {
        _pendingTasks.removeWhere((t) => t.taskId == task.taskId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task ${status.toLowerCase()} successfully'),
            backgroundColor: status == 'Approved' ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update task: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showApproveDialog(DailyTask task) async {
    final remarksController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Approve this task?', style: AppTheme.bodyMedium),
            const SizedBox(height: AppTheme.spacing12),
            TextField(
              controller: remarksController,
              decoration: InputDecoration(
                labelText: 'Remarks (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                ),
                hintText: 'Add any comments...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: AppTheme.primaryButtonStyle(AppTheme.successColor),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _updateTaskStatus(
        task,
        'Approved',
        remarks: remarksController.text.trim().isEmpty
            ? null
            : remarksController.text.trim(),
      );
    }
  }

  Future<void> _showRejectDialog(DailyTask task) async {
    final remarksController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Task'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reject this task?', style: AppTheme.bodyMedium),
            const SizedBox(height: AppTheme.spacing12),
            TextField(
              controller: remarksController,
              decoration: InputDecoration(
                labelText: 'Reason for rejection',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                ),
                hintText: 'Please provide a reason...',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (remarksController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please provide a reason for rejection'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: AppTheme.primaryButtonStyle(AppTheme.errorColor),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _updateTaskStatus(
        task,
        'Rejected',
        remarks: remarksController.text.trim(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Daily Tasks'),
        backgroundColor: AppTheme.supervisorPrimary,
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
                        onPressed: _loadPendingTasks,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadPendingTasks,
                  child: _pendingTasks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline,
                                  size: 64, color: Colors.green[300]),
                              const SizedBox(height: 16),
                              Text(
                                'No pending tasks',
                                style: AppTheme.heading3.copyWith(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'All tasks have been reviewed',
                                style: AppTheme.bodyMedium.copyWith(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(AppTheme.spacing16),
                          itemCount: _pendingTasks.length,
                          itemBuilder: (context, index) {
                            final task = _pendingTasks[index];
                            return _buildTaskCard(task);
                          },
                        ),
                ),
    );
  }

  Widget _buildTaskCard(DailyTask task) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: AppTheme.spacing16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student Name and Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Student: ${task.studentId}', // You might want to fetch student name
                        style: AppTheme.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing4),
                      Text(
                        DateFormat('MMM dd, yyyy').format(task.date),
                        style: AppTheme.bodySmall.copyWith(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing12,
                    vertical: AppTheme.spacing4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.warningColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                    border: Border.all(color: AppTheme.warningColor),
                  ),
                  child: Text(
                    task.status,
                    style: TextStyle(
                      color: AppTheme.warningColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: AppTheme.spacing12),
            
            // Competencies
            if (task.competencies.isNotEmpty) ...[
              Wrap(
                spacing: AppTheme.spacing8,
                runSpacing: AppTheme.spacing4,
                children: task.competencies.map((comp) {
                  return Chip(
                    label: Text(
                      comp.title,
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: AppTheme.supervisorPrimary.withOpacity(0.1),
                    padding: EdgeInsets.zero,
                  );
                }).toList(),
              ),
              const SizedBox(height: AppTheme.spacing12),
            ],
            
            // Task Description
            Text(
              'Task Description:',
              style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppTheme.spacing4),
            Text(
              task.taskDescription,
              style: AppTheme.bodyMedium,
            ),
            
            const SizedBox(height: AppTheme.spacing12),
            
            // Hours
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                const SizedBox(width: AppTheme.spacing4),
                Text(
                  '${task.hoursWorked.toStringAsFixed(1)} hours',
                  style: AppTheme.bodyMedium,
                ),
              ],
            ),
            
            const SizedBox(height: AppTheme.spacing16),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRejectDialog(task),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.errorColor,
                      side: BorderSide(color: AppTheme.errorColor),
                      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing12),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showApproveDialog(task),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                    style: AppTheme.primaryButtonStyle(AppTheme.successColor),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

