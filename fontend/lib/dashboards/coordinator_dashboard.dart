import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/role_dashboard.dart';
import '../widgets/role_guard.dart';
import '../widgets/stat_card.dart';
import '../widgets/section_header.dart';
import '../widgets/loading_skeleton.dart';
import '../core/app_theme.dart';
import '../widgets/error_state_widget.dart';
import '../services/cache_service.dart';
import 'coordinator_student_monitor.dart';
import '../screens/login_screen.dart';
import '../services/auth_service.dart';
import '../services/ojt_service.dart';
import '../services/prediction_service.dart';
import '../services/attendance_service.dart';
import '../services/daily_task_service.dart';
import '../services/analytics_service.dart';
import '../models/user.dart';
import '../models/ojt_record.dart';
import '../models/daily_task.dart';
import '../screens/coordinator/coordinator_supervisor_feedback_screen.dart';
import '../screens/coordinator/coordinator_performance_analysis_screen.dart';
import '../screens/coordinator/coordinator_user_approvals_screen.dart';
import '../screens/coordinator/coordinator_reports_screen.dart';
import '../screens/coordinator/coordinator_ojt_management_screen.dart';

class CoordinatorDashboard extends StatefulWidget {
  const CoordinatorDashboard({super.key});

  @override
  State<CoordinatorDashboard> createState() => _CoordinatorDashboardState();
}

class _CoordinatorDashboardState extends State<CoordinatorDashboard> {
  bool _isLoading = false;
  bool _isLoadingProfile = true;
  bool _isLoadingStats = true;
  String? _errorMessage;
  bool _isFromCache = false;
  String? _analyticsWarning;
  int _predictionFailures = 0;

  // Coordinator profile info - will be loaded from API
  String fullName = "Loading...";
  String idNumber = "N/A";
  String office = "N/A";
  String position = "OJT Coordinator";

  // Dashboard statistics / analytics (high-level)
  int _totalStudents = 0;
  int _highRiskStudents = 0;
  int _mediumRiskStudents = 0;
  int _lowRiskStudents = 0;
  int _completedOjt = 0;
  int _activeOjt = 0;
  double _averageCompletionRatio = 0;
  double _averageAttendanceRate = 0;
  String? _mostCommonCompetency;

  List<_CoordinatorStudentSnapshot> _studentSnapshots = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadDashboardStats();
  }

  // Helper method to safely call setState only if widget is still mounted
  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    try {
      setState(fn);
    } catch (e) {
      // Widget was disposed during setState - ignore silently
      debugPrint('[CoordinatorDashboard] setState called after dispose (ignored): $e');
    }
  }

  Future<void> _loadProfile() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (!mounted) return;
      if (user != null) {
        _safeSetState(() {
          fullName = user.fullName;
          idNumber = user.studentId ?? user.email;
          office = user.course ?? "OJT Office";
          position = user.role;
          _isLoadingProfile = false;
        });
      } else {
        _safeSetState(() {
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      _safeSetState(() {
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _loadDashboardStats() async {
    try {
      if (!mounted) return;
      _safeSetState(() {
        _isLoadingStats = true;
      });

      final currentUser = await AuthService.getCurrentUser();
      if (!mounted) return;
      if (currentUser?.userId == null) {
        _safeSetState(() {
          _isLoadingStats = false;
        });
        return;
      }

      // Get OJT records for this coordinator (for counts and detailed list)
      final ojtRecords = await OjtService.getOjtRecords(
        coordinatorId: currentUser!.userId,
      );
      if (!mounted) return;

      int total = ojtRecords.length;
      int completed = 0;
      int active = 0;

      for (final record in ojtRecords) {
        if (record.status == 'Completed') {
          completed++;
        } else if (record.status == 'Active' || record.status == 'Ongoing') {
          active++;
        }
      }

      Map<String, dynamic> overview = {};
      try {
        overview = await AnalyticsService.getCoordinatorOverview();
        _analyticsWarning = null;
      } catch (e) {
        debugPrint('[CoordinatorDashboard] Analytics API failed: $e');
        _analyticsWarning = 'Analytics data unavailable — showing local estimates.';
      }
      if (!mounted) return;

      // Detailed per-student snapshots (for list & modal views)
      final snapshotFutures = <Future<_CoordinatorStudentSnapshot?>>[];
      for (final record in ojtRecords) {
        snapshotFutures.add(_buildStudentSnapshot(record));
      }
      final snapshotsRaw = await Future.wait(snapshotFutures);
      if (!mounted) return;
      final snapshots =
          snapshotsRaw.whereType<_CoordinatorStudentSnapshot>().toList();

      // Derive risk counts from snapshots
      int highRisk = 0;
      int mediumRisk = 0;
      int lowRisk = 0;
      for (final snapshot in snapshots) {
        final level = snapshot.riskLevel.toUpperCase();
        if (level == 'HIGH') {
          highRisk++;
        } else if (level == 'MEDIUM') {
          mediumRisk++;
        } else if (level == 'LOW') {
          lowRisk++;
        }
      }

      // Aggregate completion & attendance
      double avgCompletionRatio = 0;
      double avgAttendanceRate = 0;
      String? topCompetency;

      if (overview.isNotEmpty) {
        final attendanceSummary =
            overview['attendance_summary'] as Map<String, dynamic>?;
        final competencySummary =
            (overview['competency_summary'] as List<dynamic>?) ?? [];

        if (attendanceSummary != null) {
          final compRatio = attendanceSummary['average_completion_ratio'];
          final attRate = attendanceSummary['average_attendance_rate'];
          if (compRatio is num) {
            avgCompletionRatio = compRatio.toDouble();
          }
          if (attRate is num) {
            avgAttendanceRate = attRate.toDouble();
          }
        }

        if (competencySummary.isNotEmpty) {
          final first = competencySummary.first;
          if (first is Map<String, dynamic>) {
            topCompetency = first['title'] as String?;
          }
        }
      } else {
        // Fallback: derive simple averages from local snapshots
        if (snapshots.isNotEmpty) {
          avgCompletionRatio = snapshots
                  .map((s) => s.completionRatio)
                  .fold<double>(0, (sum, value) => sum + value) /
              snapshots.length;
          avgAttendanceRate = snapshots
                  .map((s) => s.attendanceRate * 100)
                  .fold<double>(0, (sum, value) => sum + value) /
              snapshots.length;
        }
        topCompetency = _computeMostCommonCompetency(snapshots);
      }

      if (!mounted) return;
      _safeSetState(() {
        _totalStudents = total;
        _highRiskStudents = highRisk;
        _mediumRiskStudents = mediumRisk;
        _lowRiskStudents = lowRisk;
        _completedOjt = completed;
        _activeOjt = active;
        _studentSnapshots = snapshots;
        _averageCompletionRatio = avgCompletionRatio;
        _averageAttendanceRate = avgAttendanceRate;
        _mostCommonCompetency =
            topCompetency ?? _computeMostCommonCompetency(snapshots);
        _isLoadingStats = false;
        _isFromCache = false;
      });

      // Surface warnings to user
      _showServiceWarnings();

      // Persist to cache (TTL: 15 minutes)
      if (snapshots.isNotEmpty) {
        final userId = (await AuthService.getCurrentUser())?.userId;
        if (userId != null) {
          await CacheService.save(
            'coord_stats_$userId',
            {
              'total': total,
              'high_risk': highRisk,
              'medium_risk': mediumRisk,
              'low_risk': lowRisk,
              'completed': completed,
              'active': active,
              'avg_completion': avgCompletionRatio,
              'avg_attendance': avgAttendanceRate,
            },
            ttl: const Duration(minutes: 15),
          );
        }
      }
    } catch (e) {
      // Try stale cache
      final user = await AuthService.getCurrentUser();
      final cached = user != null
          ? await CacheService.load('coord_stats_${user.userId}', ignoreTtl: true)
          : null;
      if (cached != null) {
        _safeSetState(() {
          _totalStudents = (cached['total'] as int?) ?? 0;
          _highRiskStudents = (cached['high_risk'] as int?) ?? 0;
          _mediumRiskStudents = (cached['medium_risk'] as int?) ?? 0;
          _lowRiskStudents = (cached['low_risk'] as int?) ?? 0;
          _completedOjt = (cached['completed'] as int?) ?? 0;
          _activeOjt = (cached['active'] as int?) ?? 0;
          _averageCompletionRatio = (cached['avg_completion'] as num?)?.toDouble() ?? 0;
          _averageAttendanceRate = (cached['avg_attendance'] as num?)?.toDouble() ?? 0;
          _isLoadingStats = false;
          _isFromCache = true;
          _errorMessage = null;
        });
      } else {
        _safeSetState(() {
          _isLoadingStats = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _showServiceWarnings() {
    if (!mounted) return;
    final messages = <String>[];
    if (_analyticsWarning != null) {
      messages.add(_analyticsWarning!);
    }
    if (_predictionFailures > 0) {
      messages.add(
        'AI predictions unavailable for $_predictionFailures student(s).',
      );
      _predictionFailures = 0; // reset for next refresh
    }
    if (messages.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(messages.join('\n')),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'RETRY',
            textColor: Colors.white,
            onPressed: _loadDashboardStats,
          ),
        ),
      );
    }
  }

  String? _computeMostCommonCompetency(
      List<_CoordinatorStudentSnapshot> snapshots) {
    if (snapshots.isEmpty) return null;
    final countMap = <String, double>{};
    for (final snapshot in snapshots) {
      for (final comp in snapshot.competencies) {
        countMap.update(
          comp.title,
          (value) => value + comp.totalHours,
          ifAbsent: () => comp.totalHours,
        );
      }
    }
    if (countMap.isEmpty) return null;
    return countMap.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  Future<_CoordinatorStudentSnapshot?> _buildStudentSnapshot(
      OjtRecord record) async {
    try {
      final studentId = record.studentId;
      final requiredHours = record.requiredHours ?? 300;
      final attendanceFuture =
          AttendanceService.getAttendanceSummary(studentId);
      final competencyFuture =
          DailyTaskService.getCompetencySummary(studentId);

      Map<String, dynamic>? prediction;
      try {
        prediction = await PredictionService.getDailyPrediction(studentId);
      } catch (e) {
        debugPrint('[CoordinatorDashboard] Prediction failed for student $studentId: $e');
        prediction = null;
        _predictionFailures++;
      }

      final attendance = await attendanceFuture;
      final competencies = await competencyFuture;

      final approvedHours =
          (attendance['total_hours_completed'] as num?)?.toDouble() ?? 0;
      final presentDays = attendance['total_days_present'] as int? ??
          attendance['total_days'] as int? ??
          0;
      final attendanceRate =
          requiredHours <= 0 ? 0.0 : approvedHours / requiredHours;
      final estimatedRequiredDays = max(0, requiredHours ~/ 8);
      final absentCount = max(0, estimatedRequiredDays - presentDays);

      String riskLevel = 'LOW';
      double? riskConfidence;
      List<String> riskReasons = const [];
      String? recommendation;

      if (prediction is Map<String, dynamic>) {
        final aiPrediction =
            prediction['ai_prediction'] as Map<String, dynamic>? ?? {};
        final mlPrediction =
            aiPrediction['ml_prediction'] as Map<String, dynamic>? ?? {};
        riskLevel = (mlPrediction['risk_level'] as String? ?? 'LOW').toUpperCase();
        riskConfidence = (mlPrediction['probability'] as num?)?.toDouble();
        final reasons =
            (mlPrediction['top_reasons'] as List<dynamic>?)?.cast<String>();
        riskReasons = reasons ?? const [];
        recommendation =
            aiPrediction['recommendation'] as String? ?? mlPrediction['recommendation'] as String?;
      }

      return _CoordinatorStudentSnapshot(
        studentId: studentId,
        studentName: record.studentName ?? 'Student ${record.studentId}',
        course: record.companyName,
        supervisorName: record.supervisorName,
        requiredHours: requiredHours,
        approvedHours: approvedHours,
        attendanceRate: attendanceRate,
        presentDays: presentDays,
        absentDays: absentCount,
        lateCount: attendance['late_count'] as int? ?? 0,
        competencies: competencies,
        riskLevel: riskLevel,
        riskConfidence: riskConfidence,
        riskReasons: riskReasons,
        riskRecommendation: recommendation,
        ojtStatus: record.status,
      );
    } catch (e, stack) {
      debugPrint('[CoordinatorDashboard] Failed to load student snapshot: $e');
      debugPrint(stack.toString());
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allowedRoles: const ['coordinator', 'ojt coordinator'],
      builder: (ctx, user) => _buildCoordinatorDashboard(ctx),
    );
  }

  Widget _buildCoordinatorDashboard(BuildContext context) {
    // ✅ Loading Screen
    if (_isLoadingProfile) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/logo.gif', height: 200)
                  .animate()
                  .fadeIn(duration: 800.ms)
                  .scale(duration: 800.ms),
              const SizedBox(height: 30),
            ],
          ),
        ),
      );
    }

    return RoleDashboard(
      title: "OJT Coordinator Dashboard",
      color: AppTheme.coordinatorPrimary,
      tasks: const [],
      customActions: [
        _buildAnimatedCard(_buildProfileHeader(), delay: 0),
        
        // Statistics Section
        _buildAnimatedCard(
          SectionHeader(
            title: 'Overview',
            icon: Icons.dashboard_rounded,
          ),
          delay: 50,
        ),
        _buildAnimatedCard(_buildStatsRow(), delay: 100),
        
        _buildAnimatedCard(
          SectionHeader(
            title: 'Student Progress & Risk',
            icon: Icons.assignment_ind_rounded,
            trailing: _isLoadingStats ? null : Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.coordinatorPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$_totalStudents total',
                style: TextStyle(color: AppTheme.coordinatorPrimary, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          delay: 130,
        ),
        _buildAnimatedCard(_buildStudentListSection(), delay: 160),
        
        // Quick Actions Section
        _buildAnimatedCard(
          SectionHeader(
            title: 'Management Actions',
            icon: Icons.bolt_rounded,
          ),
          delay: 150,
        ),
        _buildAnimatedCard(
          _buildFeatureCard(
            icon: Icons.insights_rounded,
            color: Colors.blue,
            title: "Track Tasks & Attendance",
            subtitle: "View students' progress and attendance records",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const CoordinatorStudentMonitor()),
              );
            },
          ),
          delay: 200,
        ),
        _buildAnimatedCard(
          _buildFeatureCard(
            icon: Icons.feedback_rounded,
            color: Colors.orange,
            title: "Review Supervisor Feedback",
            subtitle: "Check evaluations and feedback given by supervisors",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const CoordinatorSupervisorFeedbackScreen(),
                ),
              );
            },
          ),
          delay: 400,
        ),
        _buildAnimatedCard(
          _buildFeatureCard(
            icon: Icons.analytics_rounded,
            color: Colors.purple,
            title: "Identify Performers",
            subtitle: "Analyze student performance metrics",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const CoordinatorPerformanceAnalysisScreen(),
                ),
              );
            },
          ),
          delay: 600,
        ),
        _buildAnimatedCard(
          _buildFeatureCard(
            icon: Icons.verified_user_rounded,
            color: Colors.green,
            title: "Approve Accounts",
            subtitle: "Approve new students and assigned supervisors",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CoordinatorUserApprovalsScreen(),
                ),
              );
            },
          ),
          delay: 800,
        ),
        _buildAnimatedCard(
          _buildFeatureCard(
            icon: Icons.folder_shared_rounded,
            color: Colors.teal,
            title: "Manage OJT Records",
            subtitle: "Create and manage OJT records for students",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CoordinatorOjtManagementScreen(),
                ),
              );
            },
          ),
          delay: 1000,
        ),
        _buildAnimatedCard(
          _buildFeatureCard(
            icon: Icons.message_rounded,
            color: Colors.indigo,
            title: "Communicate",
            subtitle: "Send announcements to students and supervisors",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text("Messaging functionality coming soon...")),
              );
            },
          ),
          delay: 1200,
        ),
        _buildAnimatedCard(
          _buildFeatureCard(
            icon: Icons.picture_as_pdf_rounded,
            color: Colors.red,
            title: "Create Reports",
            subtitle:
                "Generate reports on OJT activities and attendance",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CoordinatorReportsScreen(),
                ),
              );
            },
          ),
          delay: 1400,
        ),

        const SizedBox(height: 12),
        _buildAnimatedCard(_buildLogoutCard(context), delay: 1600),
      ],
    );
  }

  // --- Statistics Row ---
  Widget _buildStatsRow() {
    if (_isLoadingStats) {
      return const Padding(
        padding: EdgeInsets.all(AppTheme.spacing16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Total Students',
                  value: '$_totalStudents',
                  icon: Icons.people_rounded,
                  color: AppTheme.coordinatorPrimary,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CoordinatorStudentMonitor(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: StatCard(
                  title: 'High Risk',
                  value: '$_highRiskStudents',
                  icon: Icons.warning_amber_rounded,
                  color: AppTheme.errorColor,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const CoordinatorPerformanceAnalysisScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Medium Risk',
                  value: '$_mediumRiskStudents',
                  icon: Icons.report_problem_rounded,
                  color: Colors.orangeAccent,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const CoordinatorPerformanceAnalysisScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: 'Avg Completion %',
                   value:
                      '${(_averageCompletionRatio * 100).toStringAsFixed(0)}%',
                  icon: Icons.timer_rounded,
                  color: AppTheme.infoColor,
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: StatCard(
                  title: 'Avg Attendance %',
                   value: '${_averageAttendanceRate.toStringAsFixed(0)}%',
                  icon: Icons.calendar_today_rounded,
                  color: AppTheme.successColor,
                ),
              ),
              Expanded(
                child: StatCard(
                  title: 'Active OJT',
                   value: '$_activeOjt',
                  icon: Icons.work_history_rounded,
                  color: AppTheme.infoColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentListSection() {
    if (_isLoadingStats) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
        child: Column(
          children: [
            LoadingSkeleton(height: 120),
            SizedBox(height: 12),
            LoadingSkeleton(height: 120),
          ],
        ),
      );
    }

    if (_studentSnapshots.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
        child: Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          ),
          child: const Padding(
            padding: EdgeInsets.all(AppTheme.spacing16),
            child: Text('No students assigned yet.'),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Column(
        children: _studentSnapshots
            .map(
              (snapshot) => _CoordinatorStudentCard(
                snapshot: snapshot,
                onTap: () => _showStudentDetail(snapshot),
              ),
            )
            .toList(),
      ),
    );
  }

  void _showStudentDetail(_CoordinatorStudentSnapshot snapshot) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing12),
                  Text(
                    snapshot.studentName,
                    style: AppTheme.heading2,
                  ),
                  Text(
                    snapshot.supervisorName != null
                        ? 'Supervisor: ${snapshot.supervisorName}'
                        : 'Supervisor: Not assigned',
                    style: AppTheme.bodySmall,
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  _buildDetailAttendance(snapshot),
                  const SizedBox(height: AppTheme.spacing16),
                  _buildDetailCompetencies(snapshot),
                  const SizedBox(height: AppTheme.spacing16),
                  _buildDetailAi(snapshot),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailAttendance(_CoordinatorStudentSnapshot snapshot) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Attendance', style: AppTheme.heading3),
            const SizedBox(height: AppTheme.spacing12),
            LinearProgressIndicator(
              value: snapshot.completionRatio,
              color: AppTheme.coordinatorPrimary,
              backgroundColor: Colors.grey.shade200,
              minHeight: 10,
              borderRadius: BorderRadius.circular(12),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              '${snapshot.approvedHours.toStringAsFixed(1)} / ${snapshot.requiredHours} approved hours',
              style: AppTheme.bodySmall,
            ),
            const SizedBox(height: AppTheme.spacing12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _AttendanceStat(label: 'Present Days', value: '${snapshot.presentDays}'),
                _AttendanceStat(label: 'Late Count', value: '${snapshot.lateCount}'),
                _AttendanceStat(label: 'Estimated Absences', value: '${snapshot.absentDays}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCompetencies(_CoordinatorStudentSnapshot snapshot) {
    if (snapshot.competencies.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        ),
        child: const Padding(
          padding: EdgeInsets.all(AppTheme.spacing16),
          child: Text('No competency data yet.'),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Competency Hours', style: AppTheme.heading3),
            const SizedBox(height: AppTheme.spacing12),
            ...snapshot.competencies.map(
              (comp) => Padding(
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing6),
                child: Row(
                  children: [
                    Expanded(child: Text(comp.title, style: AppTheme.bodyMedium)),
                    Text('${comp.totalHours.toStringAsFixed(1)} hrs',
                        style: AppTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailAi(_CoordinatorStudentSnapshot snapshot) {
    final descriptor = _describeRisk(snapshot.riskLevel);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI Risk Assessment', style: AppTheme.heading3),
            const SizedBox(height: AppTheme.spacing12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing12,
                    vertical: AppTheme.spacing6,
                  ),
                  decoration: BoxDecoration(
                    color: descriptor.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                    border: Border.all(color: descriptor.color),
                  ),
                  child: Text(
                    descriptor.label,
                    style: TextStyle(
                      color: descriptor.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (snapshot.riskConfidence != null) ...[
                  const SizedBox(width: AppTheme.spacing12),
                  Text(
                    'Confidence ${(snapshot.riskConfidence! * 100).toStringAsFixed(0)}%',
                    style: AppTheme.bodySmall,
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppTheme.spacing12),
            if (snapshot.riskReasons.isNotEmpty) ...[
              Text('Top Reasons', style: AppTheme.bodyMedium),
              const SizedBox(height: AppTheme.spacing6),
              ...snapshot.riskReasons.map(
                (reason) => Row(
                  children: [
                    const Icon(Icons.bolt, size: 14, color: Colors.orange),
                    const SizedBox(width: AppTheme.spacing4),
                    Expanded(
                      child: Text(reason, style: AppTheme.bodySmall),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacing12),
            ],
            Text(
              snapshot.riskRecommendation ??
                  'No AI recommendation available yet.',
              style: AppTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  // --- Animation Wrapper ---
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

  // --- Profile Header with Gradient ---
  Widget _buildProfileHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.coordinatorPrimary,
            AppTheme.coordinatorPrimary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: [
          BoxShadow(
            color: AppTheme.coordinatorPrimary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
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
              fullName.split(" ").where((e) => e.isNotEmpty).map((e) => e[0]).take(2).join(),
              style: TextStyle(
                  color: AppTheme.coordinatorPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold),
            ),
          ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
          const SizedBox(width: AppTheme.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: AppTheme.heading2.copyWith(color: Colors.white),
                ),
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  "ID: $idNumber",
                  style: AppTheme.bodyMedium.copyWith(color: Colors.white70),
                ),
                Text(
                  "Office: $office",
                  style: AppTheme.bodyMedium.copyWith(color: Colors.white70),
                ),
                Text(
                  "Position: $position",
                  style: AppTheme.bodyMedium.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Reusable Feature Card ---
  Widget _buildFeatureCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: [AppTheme.cardShadow],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: AppTheme.spacing16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
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
                  style: AppTheme.primaryButtonStyle(AppTheme.coordinatorPrimary),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text("Logout"),
                ),
              ],
            ),
          );

          if (confirm == true) {
            _safeSetState(() => _isLoading = true);

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
                      "Securely sign out of coordinator portal",
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

class _CoordinatorStudentCard extends StatelessWidget {
  const _CoordinatorStudentCard({
    required this.snapshot,
    required this.onTap,
  });

  final _CoordinatorStudentSnapshot snapshot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final topCompetency =
        snapshot.competencies.isNotEmpty ? snapshot.competencies.first : null;
    final descriptor = _describeRisk(snapshot.riskLevel);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
      ),
      margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          snapshot.studentName,
                          style: AppTheme.bodyLarge
                              .copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          snapshot.supervisorName != null
                              ? 'Supervisor: ${snapshot.supervisorName}'
                              : 'Supervisor: Pending',
                          style: AppTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing12,
                      vertical: AppTheme.spacing6,
                    ),
                    decoration: BoxDecoration(
                      color: descriptor.color.withOpacity(0.15),
                      borderRadius:
                          BorderRadius.circular(AppTheme.borderRadiusSmall),
                      border: Border.all(color: descriptor.color),
                    ),
                    child: Text(
                      descriptor.label,
                      style: TextStyle(
                        color: descriptor.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing12),
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: snapshot.completionRatio,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                      color: AppTheme.coordinatorPrimary,
                      backgroundColor: Colors.grey.shade200,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  Text(
                    '${snapshot.approvedHours.toStringAsFixed(0)}/${snapshot.requiredHours} hrs',
                    style: AppTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing8),
              Text(
                'Attendance rate ${(snapshot.attendanceRate * 100).toStringAsFixed(0)}%',
                style: AppTheme.bodySmall,
              ),
              const SizedBox(height: AppTheme.spacing8),
              Row(
                children: [
                  const Icon(Icons.school, size: 16, color: Colors.grey),
                  const SizedBox(width: AppTheme.spacing4),
                  Expanded(
                    child: Text(
                      topCompetency != null
                          ? 'Top competency: ${topCompetency.title} (${topCompetency.totalHours.toStringAsFixed(1)} hrs)'
                          : 'No competency data yet',
                      style: AppTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              if (snapshot.riskReasons.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacing8),
                Text(
                  'AI insight: ${snapshot.riskReasons.first}',
                  style: AppTheme.caption,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceStat extends StatelessWidget {
  const _AttendanceStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(label, style: AppTheme.caption),
      ],
    );
  }
}

class _CoordinatorStudentSnapshot {
  _CoordinatorStudentSnapshot({
    required this.studentId,
    required this.studentName,
    required this.requiredHours,
    required this.approvedHours,
    required this.attendanceRate,
    required this.presentDays,
    required this.absentDays,
    required this.lateCount,
    required this.competencies,
    required this.riskLevel,
    required this.ojtStatus,
    this.course,
    this.supervisorName,
    this.riskConfidence,
    this.riskReasons = const [],
    this.riskRecommendation,
  });

  final int studentId;
  final String studentName;
  final int requiredHours;
  final double approvedHours;
  final double attendanceRate;
  final int presentDays;
  final int absentDays;
  final int lateCount;
  final List<CompetencySummary> competencies;
  final String riskLevel;
  final String ojtStatus;
  final String? course;
  final String? supervisorName;
  final double? riskConfidence;
  final List<String> riskReasons;
  final String? riskRecommendation;

  bool get isAtRisk => riskLevel == 'HIGH' || riskLevel == 'MEDIUM';

  double get completionRatio =>
      requiredHours == 0 ? 0 : (approvedHours / requiredHours).clamp(0, 1);
}

class _RiskDescriptor {
  _RiskDescriptor(this.label, this.color);

  final String label;
  final Color color;
}

_RiskDescriptor _describeRisk(String risk) {
  switch (risk.toUpperCase()) {
    case 'HIGH':
      return _RiskDescriptor('HIGH', Colors.redAccent);
    case 'MEDIUM':
      return _RiskDescriptor('MEDIUM', Colors.orangeAccent);
    case 'LOW':
    default:
      return _RiskDescriptor('LOW', AppTheme.successColor);
  }
}
