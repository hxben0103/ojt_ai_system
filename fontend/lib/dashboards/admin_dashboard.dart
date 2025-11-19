import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../widgets/role_dashboard.dart';
import '../widgets/role_guard.dart';
import '../screens/login_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool _isLoadingData = true;
  String? _errorMessage;
  List<User> _pendingCoordinators = [];
  int _totalUsers = 0;
  int _activeUsers = 0;
  int _pendingUsers = 0;
  int _coordinatorCount = 0;
  final Set<int> _processing = {};
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      setState(() {
        _isLoadingData = true;
        _errorMessage = null;
      });

      final pendingUsers = await AuthService.getPendingUsers();
      final allUsers = await AuthService.getAllUsers();

      setState(() {
        _pendingCoordinators =
            pendingUsers.where((user) => user.role == 'Coordinator').toList();
        _totalUsers = allUsers.length;
        _activeUsers =
            allUsers.where((user) => user.status == 'Active').length;
        _pendingUsers =
            allUsers.where((user) => user.status == 'Pending').length;
        _coordinatorCount =
            allUsers.where((user) => user.role == 'Coordinator').length;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
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
      await _loadDashboardData();
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

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  List<Widget> _buildCustomActions(BuildContext context) {
    final widgets = <Widget>[
      _buildHeaderCard(context),
      const SizedBox(height: 16),
    ];

    if (_isLoadingData) {
      widgets.add(_buildLoadingCard());
    } else if (_errorMessage != null) {
      widgets.add(_buildErrorCard());
    } else {
      widgets
        ..add(_buildStatsSection(context))
        ..add(const SizedBox(height: 16))
        ..add(_buildPendingSection(context));
    }

    widgets
      ..add(const SizedBox(height: 16))
      ..add(_buildLogoutCard(context));
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allowedRoles: const ['admin'],
      builder: (ctx, user) => RoleDashboard(
        title: "Admin Dashboard",
        color: Colors.indigo,
        tasks: const [],
        customActions: _buildCustomActions(ctx),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.admin_panel_settings, size: 40, color: Colors.indigo),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                "Administrative Overview",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _isLoadingData ? null : _loadDashboardData,
              icon: const Icon(Icons.refresh),
              label: const Text("Refresh"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text("Fetching latest data..."),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error, color: Colors.red),
                const SizedBox(width: 8),
                const Text(
                  "Unable to load dashboard data",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error',
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadDashboardData,
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final itemWidth = width > 600 ? (width / 2) - 32 : width - 48;

    Widget statCard(String title, String value, IconData icon, Color color) {
      return SizedBox(
        width: itemWidth,
        child: Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.15),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black54),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        statCard("Total Users", _totalUsers.toString(), Icons.group,
            Colors.indigo),
        statCard("Active Users", _activeUsers.toString(), Icons.verified_user,
            Colors.green),
        statCard("Pending Users", _pendingUsers.toString(),
            Icons.pending_actions, Colors.orange),
        statCard("Coordinators", _coordinatorCount.toString(),
            Icons.school, Colors.purple),
      ],
    );
  }

  Widget _buildPendingSection(BuildContext context) {
    if (_pendingCoordinators.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text(
              "No pending coordinator approvals. You're all caught up!",
              style: TextStyle(fontSize: 16, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_user, color: Colors.indigo),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Pending Coordinator Requests",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  label:
                      Text("${_pendingCoordinators.length} pending", style: const TextStyle(color: Colors.white)),
                  backgroundColor: Colors.indigo,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._pendingCoordinators.map((user) {
              final processing = user.userId != null &&
                  _processing.contains(user.userId);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            user.fullName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.email),
                              if (user.contactNumber != null &&
                                  user.contactNumber!.isNotEmpty)
                                Text("Contact: ${user.contactNumber}"),
                              if (user.dateCreated != null)
                                Text(
                                  "Applied on ${_dateFormat.format(user.dateCreated!)}",
                                ),
                            ],
                          ),
                          trailing: const Chip(
                            label: Text("Pending"),
                            backgroundColor: Color(0xFFFFF3E0),
                            labelStyle: TextStyle(color: Colors.orange),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: processing
                                    ? null
                                    : () => _handleDecision(user, true),
                                icon: const Icon(Icons.check),
                                label: const Text("Approve"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
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
                                  "Reject",
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
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutCard(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.logout, color: Colors.red),
        title: const Text(
          "Logout",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text("Sign out of the admin console"),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _logout(context),
      ),
    );
  }
}
