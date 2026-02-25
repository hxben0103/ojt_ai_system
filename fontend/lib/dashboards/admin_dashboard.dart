import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../widgets/role_dashboard.dart';
import '../widgets/role_guard.dart';
import '../widgets/stat_card.dart';
import '../widgets/section_header.dart';
import '../widgets/dashboard_scaffold.dart';
import '../widgets/loading_skeleton.dart';
import '../core/app_theme.dart';
import '../widgets/error_state_widget.dart';
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
            style: AppTheme.primaryButtonStyle(AppTheme.adminPrimary),
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
      const SizedBox(height: AppTheme.spacing8),
    ];

    if (_isLoadingData) {
      widgets.add(_buildLoadingCard());
    } else if (_errorMessage != null) {
      widgets.add(ErrorStateWidget(
        message: _errorMessage!,
        onRetry: _loadDashboardData,
      ));
    } else {
      widgets
        ..add(SectionHeader(
          title: 'System Overview',
          icon: Icons.dashboard_rounded,
        ))
        ..add(_buildStatsSection(context))
        ..add(const SizedBox(height: AppTheme.spacing12))
        ..add(SectionHeader(
          title: 'Pending Approvals',
          icon: Icons.pending_rounded,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.warningColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_pendingCoordinators.length}',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ))
        ..add(_buildPendingSection(context))
        ..add(const SizedBox(height: AppTheme.spacing16));
    }

    widgets.add(_buildLogoutCard(context));
    widgets.add(const SizedBox(height: AppTheme.spacing24));
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allowedRoles: const ['admin'],
      builder: (ctx, user) => RoleDashboard(
        title: "Admin Dashboard",
        color: AppTheme.adminPrimary,
        tasks: const [],
        customActions: _buildCustomActions(ctx),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: DashboardHeader(
        color: AppTheme.adminPrimary,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
          ),
          child: const Icon(
            Icons.admin_panel_settings_rounded,
            size: 32,
            color: Colors.white,
          ),
        ),
        title: "Administrative Overview",
        subtitle: "System Management & User Approvals",
        trailing: IconButton(
          onPressed: _isLoadingData ? null : _loadDashboardData,
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          tooltip: 'Refresh',
        ),
      ),
    );
  }

  Widget _buildLoadingCard() {
    return const Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing8,
      ),
      child: Column(
        children: [
          LoadingSkeleton(height: 120),
          SizedBox(height: AppTheme.spacing12),
          LoadingSkeleton(height: 160),
          SizedBox(height: AppTheme.spacing12),
          LoadingSkeleton(height: 160),
        ],
      ),
    );
  }

  // Removed _buildErrorCard — now using ErrorStateWidget

  Widget _buildStatsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Total Users',
                  value: '$_totalUsers',
                  icon: Icons.people_alt_rounded,
                  color: AppTheme.adminPrimary,
                  onTap: () {}, // Navigate to user management
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: StatCard(
                  title: 'Active Users',
                  value: '$_activeUsers',
                  icon: Icons.verified_user_rounded,
                  color: AppTheme.successColor,
                  onTap: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Pending Users',
                  value: '$_pendingUsers',
                  icon: Icons.pending_actions_rounded,
                  color: AppTheme.warningColor,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: StatCard(
                  title: 'Coordinators',
                  value: '$_coordinatorCount',
                  icon: Icons.school_rounded,
                  color: AppTheme.coordinatorPrimary,
                  onTap: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingSection(BuildContext context) {
    if (_pendingCoordinators.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.spacing32),
        margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          boxShadow: [AppTheme.cardShadow],
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.task_alt_rounded,
                size: 64,
                color: AppTheme.successColor.withOpacity(0.4),
              ),
              const SizedBox(height: AppTheme.spacing16),
              Text(
                "No pending approvals",
                style: AppTheme.heading3.copyWith(color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _pendingCoordinators.map((user) {
        final processing = user.userId != null &&
            _processing.contains(user.userId);
        return Container(
          margin: const EdgeInsets.fromLTRB(AppTheme.spacing16, 0, AppTheme.spacing16, AppTheme.spacing12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
            boxShadow: [AppTheme.cardShadow],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.adminPrimary.withOpacity(0.1),
                      radius: 28,
                      child: Text(
                        user.fullName.split(" ").where((e) => e.isNotEmpty).map((e) => e[0]).take(2).join().toUpperCase(),
                        style: TextStyle(
                          color: AppTheme.adminPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.fullName,
                            style: AppTheme.bodyLarge.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(user.email, style: AppTheme.bodySmall),
                          if (user.contactNumber != null && user.contactNumber!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(user.contactNumber!, style: AppTheme.caption),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.warningColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "COORDINATOR",
                        style: TextStyle(color: AppTheme.warningColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacing20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: processing ? null : () => _handleDecision(user, true),
                        icon: processing 
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.check_rounded, size: 20),
                        label: const Text("Approve"),
                        style: AppTheme.primaryButtonStyle(AppTheme.successColor),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: processing ? null : () => _handleDecision(user, false),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        label: const Text("Reject"),
                        style: AppTheme.secondaryButtonStyle(AppTheme.errorColor),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLogoutCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: [AppTheme.cardShadow],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        onTap: () => _logout(context),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                ),
                child: Icon(
                  Icons.power_settings_new_rounded,
                  color: AppTheme.errorColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: AppTheme.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Logout Session",
                      style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Securely sign out of admin portal",
                      style: AppTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.grey[300],
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
