import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../widgets/role_dashboard.dart';
import '../widgets/role_guard.dart';
import '../widgets/modern_stat_card.dart';
import '../widgets/section_header.dart';
import '../widgets/dashboard_scaffold.dart';
import '../widgets/loading_skeleton.dart';
import '../core/app_theme.dart';
import '../widgets/error_state_widget.dart';
import '../widgets/insight_card.dart';
import '../widgets/modern_table_card.dart';
import '../screens/login_screen.dart';
import '../screens/admin/admin_competency_management_screen.dart';
import '../screens/admin/admin_reports_screen.dart';
import '../screens/admin/admin_calendar_screen.dart';
import '../screens/admin/admin_heatmap_screen.dart';
import '../screens/coordinator/data_export_screen.dart';

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
  int _bsisCount = 0;
  int _bscsCount = 0;
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
        
        // 🛡️ Robust counting logic for Students
        _bsisCount = allUsers.where((user) {
          // Check role (flexible case)
          if (user.role.toLowerCase() != 'student') return false;
          // Consider students "Active" if they are already approved OR Ongoing
          if (user.status != 'Active' && user.status != 'Ongoing' && user.status != 'Approved') return false;
          
          final courseStr = (user.course ?? '').toUpperCase();
          final programStr = (user.program ?? '').toUpperCase();
          
          // Match BSIS, IS, or Information Systems
          return courseStr.contains('BSIS') || 
                 courseStr.contains('IS') || 
                 courseStr.contains('INFORMATION SYSTEMS') ||
                 programStr.contains('BSIS') || 
                 programStr.contains('IS');
        }).length;
        
        _bscsCount = allUsers.where((user) {
          if (user.role.toLowerCase() != 'student') return false;
          if (user.status != 'Active' && user.status != 'Ongoing' && user.status != 'Approved') return false;
          
          final courseStr = (user.course ?? '').toUpperCase();
          final programStr = (user.program ?? '').toUpperCase();
          
          // Match BSCS, CS, or Computer Science
          return courseStr.contains('BSCS') || 
                 courseStr.contains('CS') || 
                 courseStr.contains('COMPUTER SCIENCE') ||
                 programStr.contains('BSCS') || 
                 programStr.contains('CS');
        }).length;
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
        ..add(const SizedBox(height: AppTheme.spacing24))
        ..add(_buildManagementSection(context))
        ..add(const SizedBox(height: AppTheme.spacing24))
        ..add(_buildSystemHealthInsight())
        ..add(const SizedBox(height: AppTheme.spacing24))
        ..add(
          ModernTableCard(
            title: 'Coordinator Approvals',
            icon: Icons.pending_rounded,
            headerAction: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.warningColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_pendingCoordinators.length} pending',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            table: _buildPendingSection(context),
          ),
        )
        ..add(const SizedBox(height: AppTheme.spacing32));
    }

    widgets.add(_buildLogoutCard(context));
    widgets.add(const SizedBox(height: AppTheme.spacing48));
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
        dashboardData: {
          "role": "admin",
          "total_users": _totalUsers,
          "active_users": _activeUsers,
          "pending_users": _pendingUsers,
          "coordinator_count": _coordinatorCount,
        },
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
    // Explicit string conversion for JS/Web stability
    final bsisStr = _bsisCount.toString();
    final bscsStr = _bscsCount.toString();
    final pendingStr = _pendingUsers.toString();
    final coordStr = _coordinatorCount.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ModernStatCard(
                  label: 'Active BSIS',
                  value: bsisStr,
                  icon: Icons.computer_rounded,
                  color: const Color(0xFF1976D2), // Blue 700
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              Expanded(
                child: ModernStatCard(
                  label: 'Active BSCS',
                  value: bscsStr,
                  icon: Icons.code_rounded,
                  color: const Color(0xFF303F9F), // Indigo 700
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing8),
          Row(
            children: [
              Expanded(
                child: ModernStatCard(
                  label: 'Pending',
                  value: pendingStr,
                  icon: Icons.pending_actions_rounded,
                  color: const Color(0xFFEF6C00), // Warning Orange
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              Expanded(
                child: ModernStatCard(
                  label: 'Coordinators',
                  value: coordStr,
                  icon: Icons.school_rounded,
                  color: const Color(0xFF6A1B9A), // Purple 800
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManagementSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Institutional Configuration',
            icon: Icons.settings_rounded,
          ),
          const SizedBox(height: AppTheme.spacing12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
              boxShadow: [AppTheme.cardShadow],
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminCompetencyManagementScreen(),
                    ),
                  );
                },
                contentPadding: const EdgeInsets.all(AppTheme.spacing16),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.adminPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                  ),
                  child: const Icon(Icons.psychology_alt_rounded, color: AppTheme.adminPrimary),
                ),
                title: const Text(
                  'Skill Competency Matrix',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Adjust point values for different OJT skill categories.'),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
              boxShadow: [AppTheme.cardShadow],
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminReportsScreen(),
                    ),
                  );
                },
                contentPadding: const EdgeInsets.all(AppTheme.spacing16),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.indigo.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                  ),
                  child: const Icon(Icons.analytics_rounded, color: Colors.indigo),
                ),
                title: const Text(
                  'System-Wide Reports',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('View and print all coordinator summaries and system metrics.'),
                trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
          // Attendance Heatmap
          _buildManagementTile(
            context,
            title: 'Attendance Heatmap',
            subtitle: 'View system-wide student check-in locations on a live map.',
            icon: Icons.map_rounded,
            color: const Color(0xFF00897B),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminHeatmapScreen())),
          ),
          const SizedBox(height: AppTheme.spacing12),
          // University Calendar
          _buildManagementTile(
            context,
            title: 'University Calendar',
            subtitle: 'Manage PH holidays, exam weeks, and class suspensions.',
            icon: Icons.calendar_month_rounded,
            color: const Color(0xFFE53935),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCalendarScreen())),
          ),
          const SizedBox(height: AppTheme.spacing12),
          // Data Export
          _buildManagementTile(
            context,
            title: 'Data Export (CSV)',
            subtitle: 'Download attendance, student lists, and performance data as CSV.',
            icon: Icons.file_download_rounded,
            color: const Color(0xFF2E7D32),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DataExportScreen())),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementTile(BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: const [AppTheme.cardShadow],
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.all(AppTheme.spacing16),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
            ),
            child: Icon(icon, color: color),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
        ),
      ),
    );
  }


  Widget _buildSystemHealthInsight() {
    return InsightCard(
      title: "System Health Summary",
      subtitle: "Global integrity and user status",
      icon: Icons.security_rounded,
      statusLabel: _pendingUsers > 0 ? "ACTION REQUIRED" : "SYSTEM STABLE",
      statusColor: _pendingUsers > 0 ? AppTheme.warningColor : AppTheme.successColor,
      progressValue: _totalUsers > 0 ? _activeUsers / _totalUsers : 1.0,
      insights: [
        if (_pendingUsers > 0) "$_pendingUsers users across all roles awaiting registration approval.",
        "$_coordinatorCount active coordinators managing OJT records.",
        "Overall system user compliance: ${(_totalUsers > 0 ? (_activeUsers / _totalUsers * 100) : 100).toInt()}%",
      ],
      recommendation: _pendingUsers > 0 
          ? "Review pending coordinator and student applications to prevent onboarding delays." 
          : "System integrity checks passed. All users are verified.",
      onRetry: _loadDashboardData,
    );
  }

  Widget _buildPendingSection(BuildContext context) {
    if (_pendingCoordinators.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppTheme.spacing32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.task_alt_rounded, size: 48, color: Colors.grey),
              SizedBox(height: 12),
              Text("No pending coordinator approvals", style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (_pendingCoordinators.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_pendingCoordinators.length} Pending Approvals',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                TextButton.icon(
                  onPressed: _processing.isNotEmpty ? null : () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Approve All'),
                        content: Text('Approve all ${_pendingCoordinators.length} pending coordinators?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                            child: const Text('Approve All'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      setState(() {
                        for (final u in _pendingCoordinators) {
                          if (u.userId != null) _processing.add(u.userId!);
                        }
                      });
                      try {
                        final ids = _pendingCoordinators.map((u) => u.userId!).toList();
                        await AuthService.batchApprove(ids, 'approve');
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All coordinators approved')));
                        _loadDashboardData();
                      } catch (e) {
                         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Batch approval failed: $e')));
                      } finally {
                        if (mounted) setState(() => _processing.clear());
                      }
                    }
                  },
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('Approve All'),
                  style: TextButton.styleFrom(foregroundColor: Colors.green),
                ),
              ],
            ),
          ),
        ..._pendingCoordinators.map((user) {
        final processing = user.userId != null && _processing.contains(user.userId);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppTheme.adminPrimary.withOpacity(0.1),
                    child: Text(user.fullName[0], style: TextStyle(color: AppTheme.adminPrimary, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.fullName, style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                        Text(user.email, style: AppTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: processing ? null : () => _handleDecision(user, true),
                      style: AppTheme.primaryButtonStyle(AppTheme.successColor).copyWith(
                        padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 8)),
                      ),
                      child: processing ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("Approve"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: processing ? null : () => _handleDecision(user, false),
                      style: AppTheme.secondaryButtonStyle(AppTheme.errorColor).copyWith(
                        padding: WidgetStateProperty.all(const EdgeInsets.symmetric(vertical: 8)),
                      ),
                      child: const Text("Reject"),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
            ],
          ),
        );
      }).toList(),
      ],
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

