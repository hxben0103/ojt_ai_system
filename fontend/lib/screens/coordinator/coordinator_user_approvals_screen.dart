import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../models/user.dart';

class CoordinatorUserApprovalsScreen extends StatefulWidget {
  const CoordinatorUserApprovalsScreen({super.key});

  @override
  State<CoordinatorUserApprovalsScreen> createState() =>
      _CoordinatorUserApprovalsScreenState();
}

class _CoordinatorUserApprovalsScreenState
    extends State<CoordinatorUserApprovalsScreen> {
  List<User> _pendingStudents = [];
  List<User> _pendingSupervisors = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Set<int> _processing = {};
  final Set<int> _selectedUsers = {};
  bool _selectAll = false;
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _loadPendingUsers();
  }

  Future<void> _loadPendingUsers() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _selectedUsers.clear();
        _selectAll = false;
      });

      final pendingUsers = await AuthService.getPendingUsers();
      setState(() {
        _pendingStudents =
            pendingUsers.where((u) => u.role.toLowerCase() == 'student').toList();
        _pendingSupervisors = pendingUsers
            .where((u) => u.role.toLowerCase() == 'supervisor' ||
                u.role.toLowerCase() == 'industry supervisor')
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _handleDecision(User user, bool approve) async {
    if (user.userId == null) return;
    setState(() {
      _processing.add(user.userId!);
    });
    try {
      if (approve) {
        await AuthService.approveUser(user.userId!);
      } else {
        await AuthService.rejectUser(user.userId!);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approve
                  ? 'Approved ${user.fullName}'
                  : 'Rejected ${user.fullName}',
            ),
          ),
        );
      }
      await _loadPendingUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processing.remove(user.userId);
        });
      }
    }
  }

  Future<void> _handleBatchAction(String action) async {
    if (_selectedUsers.isEmpty) return;
    
    final actionLabel = action == 'approve' ? 'approve' : 'reject';
    final count = _selectedUsers.length;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Batch ${action[0].toUpperCase()}${action.substring(1)}'),
        content: Text('Are you sure you want to $actionLabel $count user(s)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'approve' ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('${action[0].toUpperCase()}${action.substring(1)} All'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      for (final id in _selectedUsers) {
        _processing.add(id);
      }
    });

    try {
      final result = await AuthService.batchApprove(_selectedUsers.toList(), action);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Batch $action complete'),
            backgroundColor: action == 'approve' ? Colors.green : Colors.orange,
          ),
        );
      }
      await _loadPendingUsers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Batch $action failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processing.clear();
        });
      }
    }
  }

  void _toggleSelectAll(List<User> currentList) {
    setState(() {
      if (_selectAll) {
        _selectedUsers.clear();
        _selectAll = false;
      } else {
        for (final user in currentList) {
          if (user.userId != null) _selectedUsers.add(user.userId!);
        }
        _selectAll = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Approve Users'),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              bottom: TabBar(
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Students'),
                        if (_pendingStudents.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_pendingStudents.length}',
                              style: const TextStyle(
                                color: Colors.deepPurple,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Supervisors'),
                        if (_pendingSupervisors.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_pendingSupervisors.length}',
                              style: const TextStyle(
                                color: Colors.deepPurple,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                // Select All toggle
                if (!_isLoading && _errorMessage == null)
                  IconButton(
                    icon: Icon(_selectAll ? Icons.deselect : Icons.select_all),
                    tooltip: _selectAll ? 'Deselect All' : 'Select All',
                    onPressed: () {
                      final tabIndex = DefaultTabController.of(context).index;
                      final currentList = tabIndex == 0 ? _pendingStudents : _pendingSupervisors;
                      _toggleSelectAll(currentList);
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadPendingUsers,
                ),
              ],
            ),
            body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text('Error: $_errorMessage'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadPendingUsers,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: TabBarView(
                              children: [
                                _buildUserList(_pendingStudents),
                                _buildUserList(_pendingSupervisors),
                              ],
                            ),
                          ),
                          // Batch Action Bar
                          if (_selectedUsers.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, -2),
                                  ),
                                ],
                              ),
                              child: SafeArea(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurple.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '${_selectedUsers.length} selected',
                                        style: const TextStyle(
                                          color: Colors.deepPurple,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    ElevatedButton.icon(
                                      onPressed: _processing.isNotEmpty ? null : () => _handleBatchAction('approve'),
                                      icon: const Icon(Icons.check_circle, size: 18),
                                      label: const Text('Approve All'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      onPressed: _processing.isNotEmpty ? null : () => _handleBatchAction('reject'),
                                      icon: const Icon(Icons.cancel, size: 18, color: Colors.red),
                                      label: const Text('Reject All', style: TextStyle(color: Colors.red)),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Colors.red),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
          );
        },
      ),
    );
  }

  Widget _buildUserList(List<User> users) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
                size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No pending approvals',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPendingUsers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          final processing = user.userId != null &&
              _processing.contains(user.userId);
          final isSelected = user.userId != null && _selectedUsers.contains(user.userId);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: isSelected
                  ? const BorderSide(color: Colors.deepPurple, width: 2)
                  : BorderSide.none,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Checkbox for batch selection
                      Checkbox(
                        value: isSelected,
                        activeColor: Colors.deepPurple,
                        onChanged: (val) {
                          setState(() {
                            if (val == true && user.userId != null) {
                              _selectedUsers.add(user.userId!);
                            } else if (user.userId != null) {
                              _selectedUsers.remove(user.userId);
                              _selectAll = false;
                            }
                          });
                        },
                      ),
                      CircleAvatar(
                        backgroundColor: Colors.deepPurple.withOpacity(0.1),
                        child: Text(
                          () {
                            final initials = user.fullName
                                .split(' ')
                                .where((e) => e.isNotEmpty)
                                .map((e) => e[0])
                                .take(2)
                                .join()
                                .toUpperCase();
                            return initials.isNotEmpty ? initials : 'U';
                          }(),
                          style: const TextStyle(color: Colors.deepPurple),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.fullName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(user.email),
                            if (user.contactNumber != null &&
                                user.contactNumber!.isNotEmpty)
                              Text('Contact: ${user.contactNumber}'),
                            if (user.course != null)
                              Text('Course: ${user.course}'),
                            if (user.dateCreated != null)
                              Text(
                                'Applied: ${_dateFormat.format(user.dateCreated!)}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Chip(
                        label: const Text('Pending'),
                        backgroundColor: Colors.orange.shade100,
                        labelStyle: const TextStyle(color: Colors.orange),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: processing
                              ? null
                              : () => _handleDecision(user, true),
                          icon: const Icon(Icons.check),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: processing
                              ? null
                              : () => _handleDecision(user, false),
                          icon: const Icon(Icons.close, color: Colors.red),
                          label: const Text(
                            'Reject',
                            style: TextStyle(color: Colors.red),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                          ),
                        ),
                      ),
                    ],
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

