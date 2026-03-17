import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../providers/supervisor_provider.dart';
import '../widgets/role_dashboard.dart';
import '../widgets/role_guard.dart';
import '../widgets/modern_stat_card.dart';
import '../widgets/section_header.dart';
import '../widgets/loading_skeleton.dart';
import '../core/app_theme.dart';
import '../widgets/error_state_widget.dart';
import '../widgets/insight_card.dart';
import '../widgets/modern_table_card.dart';
import '../widgets/integrity_badge.dart';
import 'supervisor_daily_tasks_review_screen.dart';
import '../screens/login_screen.dart';
import '../services/auth_service.dart';
import '../models/attendance.dart';
import '../screens/supervisor/supervisor_evaluation_form_screen.dart';

class SupervisorDashboard extends StatefulWidget {
  const SupervisorDashboard({super.key});

  @override
  State<SupervisorDashboard> createState() => _SupervisorDashboardState();
}

class _SupervisorDashboardState extends State<SupervisorDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupervisorProvider>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allowedRoles: const ['supervisor', 'industry supervisor'],
      builder: (ctx, user) => Consumer<SupervisorProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (provider.errorMessage != null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Supervisor Dashboard')),
              body: ErrorStateWidget(
                message: provider.errorMessage!,
                onRetry: () => provider.refresh(),
              ),
            );
          }

          return _buildDashboardContent(context, provider);
        },
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context, SupervisorProvider provider) {
    return RoleDashboard(
      title: "Industry Supervisor Dashboard",
      color: AppTheme.supervisorPrimary,
      tasks: const [],
      dashboardData: {
        "role": "supervisor",
        "total_assigned": provider.totalAssigned,
        "pending_evaluations": provider.pendingEvaluations,
        "high_risk_students": provider.highRiskStudents,
        "average_forecast_score": provider.averageForecastedGrade,
      },
      customActions: [
        _buildAnimatedCard(_buildProfileHeader(provider), delay: 0),
        const SizedBox(height: AppTheme.spacing12),
        
        // Statistics Section
        _buildAnimatedCard(
          SectionHeader(
            title: 'Overview',
            icon: Icons.dashboard_rounded,
          ),
          delay: 50,
        ),
        _buildAnimatedCard(_buildStatsRow(provider), delay: 100),
        const SizedBox(height: AppTheme.spacing24),
        
        _buildAnimatedCard(_buildEvaluationInsight(provider), delay: 130),
        const SizedBox(height: AppTheme.spacing24),
        
        if (provider.assignedStudents.isNotEmpty) ...[
          _buildAnimatedCard(
            ModernTableCard(
              title: 'Assigned Students',
              icon: Icons.people_rounded,
              table: _buildStudentTable(provider),
            ),
            delay: 160,
          ),
          const SizedBox(height: AppTheme.spacing24),
        ],
        
        _buildAnimatedCard(_buildManagementGroup(), delay: 200),

        const SizedBox(height: AppTheme.spacing32),
        _buildAnimatedCard(_buildLogoutCard(context), delay: 650),
        const SizedBox(height: AppTheme.spacing48),
      ],
    );
  }

  // --- Animated Wrapper ---
  Widget _buildAnimatedCard(Widget child, {int delay = 0}) {
    return Animate(
      effects: [
        FadeEffect(duration: 600.ms, delay: delay.ms),
        SlideEffect(
            begin: const Offset(0, 0.2),
            end: Offset.zero,
            delay: delay.ms,
            duration: 600.ms),
      ],
      child: child,
    );
  }

  Widget _buildEvaluationInsight(SupervisorProvider provider) {
    if (provider.isLoadingStudents) return const SizedBox.shrink();
    
    final bool allDone = provider.pendingEvaluations == 0 && provider.totalAssigned > 0;
    final int needingAttention = provider.highRiskStudents;
    
    return InsightCard(
      title: "Mentoring Recommendations",
      subtitle: "Review feedback and performance monitoring",
      icon: Icons.fact_check_rounded,
      statusLabel: needingAttention > 0 ? "$needingAttention Needs Attention" : (allDone ? "ALL COMPLETED" : "${provider.pendingEvaluations ?? 0} Pending"),
      statusColor: needingAttention > 0 ? AppTheme.errorColor : (allDone ? AppTheme.successColor : AppTheme.warningColor),
      progressValue: provider.totalAssigned > 0 ? ((provider.totalAssigned - provider.pendingEvaluations) / provider.totalAssigned).clamp(0.0, 1.0) : 1.0,
      insights: [
        if (needingAttention > 0) "$needingAttention students are flagging poor attendance or low progress scores.",
        if (provider.pendingEvaluations > 0) "${provider.pendingEvaluations ?? 0} students awaiting end-of-term evaluation.",
        if (provider.totalAssigned > 0) "Total assigned students: ${provider.totalAssigned ?? 0}",
      ],
      recommendation: needingAttention > 0 
          ? "Immediate 1-on-1 mentoring recommended for flagged students." 
          : (provider.pendingEvaluations > 0 ? "Complete pending evaluations to finalize student grades." : "All assigned students have been evaluated for this term."),
    );
  }

  Widget _buildStudentTable(SupervisorProvider provider) {
    if (provider.assignedStudents.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.spacing24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.people_outline_rounded, size: 48, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text('No students assigned yet.', style: AppTheme.bodySmall),
            ],
          ),
        ),
      );
    }
    
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
        columnSpacing: 24,
        horizontalMargin: 16,
        dataRowMaxHeight: 65,
        dataRowMinHeight: 60,
        columns: const [
          DataColumn(label: Text('Student', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Attendance Consistency', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Pending Evaluations', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: provider.assignedStudents.map((record) {
          final Attendance? todayRecord = provider.todayAttendanceMap[record.studentId];
          final hasFlag = todayRecord?.verificationStatus == 'FLAGGED';
          
          return DataRow(
            cells: [
              DataCell(
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: AppTheme.supervisorPrimary.withOpacity(0.1),
                      child: Text(
                        (record.studentName ?? "S")[0].toUpperCase(),
                        style: TextStyle(color: AppTheme.supervisorPrimary, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Text(
                        record.studentName ?? 'Unknown Student',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              DataCell(
                Row(
                  children: [
                    Icon(hasFlag ? Icons.warning_amber_rounded : Icons.check_circle_outline, 
                         color: hasFlag ? AppTheme.errorColor : AppTheme.successColor, size: 16),
                    const SizedBox(width: 4),
                    Text(hasFlag ? 'Poor' : 'Consistent', 
                         style: TextStyle(fontSize: 13, color: hasFlag ? AppTheme.errorColor : AppTheme.successColor, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              DataCell(
                 Text(record.status == 'Evaluation Pending' ? '1 Pending' : 'None', 
                     style: TextStyle(fontSize: 13, color: record.status == 'Evaluation Pending' ? AppTheme.warningColor : Colors.grey.shade700)),
              ),
              DataCell(
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupervisorEvaluationFormScreen())),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    ),
  );
  },
  );
}

  Widget _buildFlagIndicator(Attendance record) {
    if (record.verificationStatus == 'FLAGGED') {
      final bool isOut = record.morningOut != null ||
          record.afternoonOut != null ||
          record.overtimeOut != null ||
          record.timeOut != null;
      return IntegrityBadge.flagged(isOut: isOut, isCompact: true);
    }

    if (record.verificationStatus == 'AUTO_VERIFIED' || record.verified) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.successColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_user_rounded,
                size: 10, color: AppTheme.successColor),
            const SizedBox(width: 4),
            Text(
              'Verified',
              style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.successColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 9),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildManagementGroup() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          _actionTile(
            const Icon(Icons.people_alt_rounded, color: Colors.teal),
            "Monitor & Evaluate Students",
            "Track assigned students' progress and submit final evaluations",
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupervisorEvaluationFormScreen())),
          ),
          Divider(height: 1, color: Colors.grey[100]),
          _actionTile(
            const Icon(Icons.fact_check_rounded, color: Colors.indigo),
            "Daily Task Review",
            "Approve or reject work submissions",
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupervisorDailyTasksReviewScreen())),
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _actionTile(Widget icon, String title, String subtitle, VoidCallback onTap, {bool isLast = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: isLast ? const BorderRadius.vertical(bottom: Radius.circular(16)) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(10)),
              child: icon,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
                  Text(subtitle, style: AppTheme.bodySmall.copyWith(color: Colors.grey[500])),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[300], size: 18),
          ],
        ),
      ),
    );
  }

  // --- Profile Header with Gradient & Shadow ---
  Widget _buildProfileHeader(SupervisorProvider provider) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.supervisorPrimary,
            AppTheme.supervisorPrimary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: [
          BoxShadow(
            color: AppTheme.supervisorPrimary.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Row(
        children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: Colors.white,
            child: Text(
              provider.fullName.split(" ").where((e) => e.isNotEmpty).map((e) => e[0]).take(2).join(),
              style: TextStyle(
                color: AppTheme.supervisorPrimary,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
          const SizedBox(width: AppTheme.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.fullName,
                  style: AppTheme.heading2.copyWith(color: Colors.white),
                ),
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  "ID: ${provider.idNumber?.isNotEmpty == true ? provider.idNumber : 'Unavailable'}",
                  style: AppTheme.bodyMedium.copyWith(color: Colors.white70),
                ),
                Text(
                  "Office: ${provider.office?.isNotEmpty == true ? provider.office : 'Not specified'}",
                  style: AppTheme.bodyMedium.copyWith(color: Colors.white70),
                ),
                Text(
                  "Position: ${provider.position?.isNotEmpty == true ? provider.position : 'Supervisor'}",
                  style: AppTheme.bodyMedium.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Statistics Row (compact) ---
  Widget _buildStatsRow(SupervisorProvider provider) {
    if (provider.isLoadingStudents) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
        child: LoadingSkeleton(height: 88),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Row(
        children: [
          Expanded(
            child: ModernStatCard(
              label: 'Assigned',
              value: '${provider.totalAssigned ?? 0}',
              icon: Icons.people_rounded,
              color: AppTheme.supervisorPrimary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SupervisorEvaluationFormScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: ModernStatCard(
              label: 'Pending Evaluations',
              value: '${provider.pendingEvaluations ?? 0}',
              icon: Icons.assignment_rounded,
              color: AppTheme.warningColor,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SupervisorEvaluationFormScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: ModernStatCard(
              label: 'Students Needing Attention',
              value: '${provider.highRiskStudents ?? 0}',
              icon: Icons.warning_amber_rounded,
              color: provider.highRiskStudents > 0 ? AppTheme.errorColor : AppTheme.successColor,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SupervisorEvaluationFormScreen(),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: ModernStatCard(
              label: 'Average Forecast Score',
              value: provider.averageForecastedGrade > 0
                  ? provider.averageForecastedGrade.toStringAsFixed(1)
                  : 'N/A',
              icon: Icons.school_rounded,
              color: Colors.blue.shade700,
            ),
          ),
        ],
      ),
    );
  }

  // --- Logout Card ---
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
        onTap: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Confirm Logout"),
              content: const Text(
                  "Are you sure you want to log out of your account?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: AppTheme.primaryButtonStyle(AppTheme.supervisorPrimary),
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
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            }
          }
        },
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
                      "Securely sign out of supervisor portal",
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
