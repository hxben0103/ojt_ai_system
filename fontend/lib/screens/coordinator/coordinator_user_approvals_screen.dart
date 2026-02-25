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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
                : TabBarView(
                    children: [
                      _buildUserList(_pendingStudents),
                      _buildUserList(_pendingSupervisors),
                    ],
                  ),
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

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
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

