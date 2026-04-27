import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
import '../screens/supervisor/student_detail_screen.dart';
import '../screens/login_screen.dart';
import '../services/auth_service.dart';
import '../models/attendance.dart';
import '../screens/supervisor/supervisor_evaluation_form_screen.dart';
import '../screens/supervisor/supervisor_overtime_requests_screen.dart';

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
          const SectionHeader(
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
    if (provider.isLoadingStudents) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
        child: LoadingSkeleton(height: 180),
      );
    }
    
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
        padding: const EdgeInsets.all(AppTheme.spacing32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.people_outline_rounded, size: 48, color: Colors.blueGrey.shade200),
              const SizedBox(height: 12),
              Text('No students assigned yet.', style: AppTheme.bodySmall),
            ],
          ),
        ),
      );
    }
    
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.blueGrey.shade50,
        dataTableTheme: DataTableThemeData(
          headingTextStyle: AppTheme.caption.copyWith(fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 1),
          dataTextStyle: AppTheme.bodyMedium.copyWith(fontSize: 13),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                horizontalMargin: 20,
                columnSpacing: 12,
                dataRowMinHeight: 70,
                dataRowMaxHeight: 75,
                headingRowHeight: 56,
                showCheckboxColumn: false,
                columns: const [
                  DataColumn(label: Text('STUDENT')),
                  DataColumn(label: Text('INTEGRITY STATUS')),
                  DataColumn(label: Text('EVALUATION')),
                  DataColumn(label: Text('TIMELINE')),
                  DataColumn(label: Text('ACTION')),
                ],
                rows: provider.assignedStudents.map((record) {
                  final Attendance? todayRecord = provider.todayAttendanceMap[record.studentId];
                  final hasFlag = todayRecord?.verificationStatus == 'FLAGGED';
                  
                  return DataRow(
                    onSelectChanged: (_) => Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (_) => StudentDetailScreen(record: record))
                    ),
                    cells: [
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppTheme.supervisorPrimary.withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                (record.studentName ?? "S")[0].toUpperCase(),
                                style: AppTheme.heading3.copyWith(color: AppTheme.supervisorPrimary, fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              record.studentName ?? 'Unknown Student',
                              style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        Builder(builder: (context) {
                          final String risk = record.riskLevel ?? 'LOW';
                          final bool missingToday = todayRecord == null;
                          
                          if (missingToday) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.blueGrey.shade100, width: 1),
                              ),
                              child: Text('NO SIGN-IN', 
                                   style: AppTheme.caption.copyWith(fontSize: 8, color: Colors.blueGrey.shade500, fontWeight: FontWeight.w800)),
                            );
                          }

                          Color statusColor = AppTheme.successColor;
                          String statusText = 'CONSISTENT';

                          if (risk == 'HIGH' || hasFlag) {
                            statusColor = AppTheme.errorColor;
                            statusText = hasFlag ? 'FLAGGED' : 'AT RISK';
                          } else if (risk == 'MEDIUM') {
                            statusColor = AppTheme.warningColor;
                            statusText = 'IRREGULAR';
                          }

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: statusColor.withOpacity(0.1), width: 1),
                            ),
                            child: Text(statusText, 
                                 style: AppTheme.caption.copyWith(fontSize: 8, color: statusColor, fontWeight: FontWeight.w800)),
                          );
                        }),
                      ),
                      DataCell(
                         Text(record.status == 'Evaluation Pending' ? '1 Pending' : 'None', 
                             style: AppTheme.bodyMedium.copyWith(
                               color: record.status == 'Evaluation Pending' ? AppTheme.warningColor : Colors.blueGrey.shade500,
                               fontWeight: record.status == 'Evaluation Pending' ? FontWeight.w700 : FontWeight.w500,
                               fontSize: 12,
                             )),
                      ),
                      DataCell(
                         Text(record.endDate != null ? DateFormat('MMM dd, yyyy').format(record.endDate!) : 'N/A', 
                             style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w600, color: Colors.blueGrey.shade600, fontSize: 12)),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppTheme.supervisorPrimary.withOpacity(0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.supervisorPrimary.withOpacity(0.4), size: 12),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
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
            const Icon(Icons.verified_user_rounded,
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _actionTile(
            const Icon(Icons.people_alt_rounded, color: Colors.teal, size: 20),
            "Monitor & Evaluate Students",
            "Review progress and submit evaluations",
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupervisorEvaluationFormScreen())),
          ),
          const SizedBox(height: 12),
          _actionTile(
            const Icon(Icons.more_time_rounded, color: Colors.purple, size: 20),
            "Overtime Approvals",
            "Review and approve student overtime requests",
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupervisorOvertimeRequestsScreen())),
          ),
          const SizedBox(height: 12),
          _actionTile(
            const Icon(Icons.fact_check_rounded, color: Colors.indigo, size: 20),
            "Daily Task Review",
            "Audit work submissions & logs",
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupervisorDailyTasksReviewScreen())),
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _actionTile(Widget icon, String title, String subtitle, VoidCallback onTap, {bool isLast = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: Colors.blueGrey.shade100, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: icon,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: AppTheme.bodySmall.copyWith(color: Colors.blueGrey.shade500)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.chevron_right_rounded, color: Colors.blueGrey.shade400, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Professional Enterprise Hero Header ---
  Widget _buildProfileHeader(SupervisorProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppTheme.supervisorPrimary,
            Color(0xFF065F46), // A slightly lighter emerald for depth
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.supervisorPrimary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5),
                ),
                child: CircleAvatar(
                  radius: 36,
                  backgroundImage: provider.profileImageBytes != null ? MemoryImage(provider.profileImageBytes!) : null,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: provider.profileImageBytes == null
                      ? Text(
                          provider.fullName.isNotEmpty ? provider.fullName[0].toUpperCase() : "S",
                          style: AppTheme.heading1.copyWith(color: Colors.white, fontSize: 32),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.fullName,
                      style: AppTheme.heading2.copyWith(color: Colors.white, fontSize: 22),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.badge_rounded, size: 12, color: Colors.teal.shade100),
                          const SizedBox(width: 6),
                          Text(
                            provider.position.toUpperCase(),
                            style: AppTheme.caption.copyWith(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 10,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildModernProfileStat("ID Number", provider.idNumber, Icons.fingerprint_rounded),
              const SizedBox(width: 16),
              _buildModernProfileStat("Dept/Office", provider.office, Icons.business_center_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModernProfileStat(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: Colors.teal.shade200),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                  Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
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
        boxShadow: const [AppTheme.cardShadow],
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
                child: const Icon(
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

