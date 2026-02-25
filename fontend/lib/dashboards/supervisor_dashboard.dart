import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/role_dashboard.dart';
import '../widgets/role_guard.dart';
import '../widgets/stat_card.dart';
import '../widgets/section_header.dart';
import '../widgets/info_tile.dart';
import '../widgets/loading_skeleton.dart';
import '../core/app_theme.dart';
import '../widgets/error_state_widget.dart';
import '../services/cache_service.dart';
import 'supervisor_student_monitor.dart';
import 'supervisor_attendance_verification_screen.dart';
import 'supervisor_daily_tasks_review_screen.dart';
import '../screens/login_screen.dart';
import '../services/auth_service.dart';
import '../services/ojt_service.dart';
import '../services/evaluation_service.dart';
import '../models/user.dart';
import '../models/ojt_record.dart';
import '../screens/supervisor/supervisor_evaluation_form_screen.dart';

class SupervisorDashboard extends StatefulWidget {
  const SupervisorDashboard({super.key});

  @override
  State<SupervisorDashboard> createState() => _SupervisorDashboardState();
}

class _SupervisorDashboardState extends State<SupervisorDashboard> {
  // Profile info will be loaded from API
  String fullName = "Loading...";
  String idNumber = "N/A";
  String office = "N/A";
  String position = "Industry Supervisor";
  bool _isLoading = true;
  bool _isLoadingStudents = true;
  String? _errorMessage;
  bool _isFromCache = false;

  // Dashboard data
  List<OjtRecord> _assignedStudents = [];
  int _pendingEvaluations = 0;
  int _totalAssigned = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadAssignedStudents();
  }

  Future<void> _loadProfile() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user != null) {
        setState(() {
          fullName = user.fullName;
          // Use actual user ID for supervisors instead of student-specific fields
          idNumber = user.userId?.toString() ?? user.email;
          office = user.course ?? "N/A";
          position = user.role;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAssignedStudents() async {
    try {
      setState(() {
        _isLoadingStudents = true;
      });

      final currentUser = await AuthService.getCurrentUser();
      if (currentUser?.userId == null) {
        setState(() {
          _isLoadingStudents = false;
        });
        return;
      }

      final supervisorId = currentUser!.userId!;
      debugPrint('[SupervisorDashboard] Loading assigned students for supervisor ID: $supervisorId');

      // Get ALL OJT records assigned to this supervisor (Active, Ongoing, etc.)
      // Don't filter by status to count all assigned students
      final ojtRecords = await OjtService.getOjtRecords(
        supervisorId: supervisorId,
        // Remove status filter to get all assigned students
      );

      debugPrint('[SupervisorDashboard] Found ${ojtRecords.length} assigned student(s)');

      // Count pending evaluations
      int pendingCount = 0;
      for (final record in ojtRecords) {
        try {
          final evaluations = await EvaluationService.getEvaluations(
            studentId: record.studentId,
            supervisorId: supervisorId,
          );
          // Consider evaluation pending if there is no COMPLETED evaluation yet
          final hasCompleted = evaluations.any(
            (e) => (e.status ?? '').toLowerCase() == 'completed',
          );
          if (!hasCompleted) {
            pendingCount++;
          }
        } catch (e) {
          debugPrint('[SupervisorDashboard] Error checking evaluations for student ${record.studentId}: $e');
          // Count as pending if we can't check (safer to show as pending)
          pendingCount++;
        }
      }

      debugPrint('[SupervisorDashboard] Total assigned: ${ojtRecords.length}, Pending evaluations: $pendingCount');

      // Cache for offline use (TTL: 20 minutes)
      await CacheService.save(
        'supervisor_students_$supervisorId',
        {
          'total': ojtRecords.length,
          'pending_evaluations': pendingCount,
        },
        ttl: const Duration(minutes: 20),
      );

      setState(() {
        _assignedStudents = ojtRecords;
        _totalAssigned = ojtRecords.length;
        _pendingEvaluations = pendingCount;
        _isLoadingStudents = false;
        _isFromCache = false;
      });
    } catch (e, stackTrace) {
      debugPrint('[SupervisorDashboard] Error loading assigned students: $e');
      debugPrint('[SupervisorDashboard] Stack trace: $stackTrace');

      // Try stale cache
      final user = await AuthService.getCurrentUser();
      final supervisorId = user?.userId;
      final cached = supervisorId != null
          ? await CacheService.load('supervisor_students_$supervisorId', ignoreTtl: true)
          : null;

      if (cached != null && mounted) {
        setState(() {
          _totalAssigned = (cached['total'] as int?) ?? 0;
          _pendingEvaluations = (cached['pending_evaluations'] as int?) ?? 0;
          _isLoadingStudents = false;
          _isFromCache = true;
          _errorMessage = null;
        });
      } else {
        setState(() {
          _assignedStudents = [];
          _totalAssigned = 0;
          _pendingEvaluations = 0;
          _isLoadingStudents = false;
          _errorMessage = 'Failed to load student data. Please check your connection.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allowedRoles: const ['supervisor', 'industry supervisor'],
      builder: (ctx, user) => _buildSupervisorDashboard(ctx),
    );
  }

  Widget _buildSupervisorDashboard(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Supervisor Dashboard')),
        body: ErrorStateWidget(
          message: _errorMessage!,
          onRetry: () {
            setState(() => _errorMessage = null);
            _loadAssignedStudents();
          },
        ),
      );
    }

    return RoleDashboard(
      title: "Industry Supervisor Dashboard",
      color: AppTheme.supervisorPrimary,
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
        
        // Assigned Students Section
        if (_assignedStudents.isNotEmpty) ...[
          _buildAnimatedCard(
            SectionHeader(
              title: 'Assigned Students',
              icon: Icons.people_rounded,
              trailing: _isLoadingStudents ? null : Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.supervisorPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_assignedStudents.length} students',
                  style: TextStyle(color: AppTheme.supervisorPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            delay: 150,
          ),
          ..._assignedStudents.take(3).toList().asMap().entries.map((entry) => 
            _buildAnimatedCard(
              _buildStudentTile(_assignedStudents[entry.key]),
              delay: 200 + ((entry.key as int) * 50),
            ),
          ),
          if (_assignedStudents.length > 3)
            _buildAnimatedCard(
              _buildViewAllStudentsCard(),
              delay: 350,
            ),
        ],
        
        // Quick Actions Section
        _buildAnimatedCard(
          SectionHeader(
            title: 'Management Actions',
            icon: Icons.bolt_rounded,
          ),
          delay: 400,
        ),
        _buildAnimatedCard(_buildFeatureCard(
          icon: Icons.assessment_rounded,
          color: Colors.blue,
          title: "Submit Evaluations",
          subtitle: "Evaluate students and submit feedback",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SupervisorEvaluationFormScreen(),
              ),
            );
          },
        ), delay: 450),
        _buildAnimatedCard(_buildFeatureCard(
          icon: Icons.insights_rounded,
          color: Colors.orange,
          title: "Monitor Progress",
          subtitle: "View students' OJT hours and attendance",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SupervisorStudentMonitorScreen(),
              ),
            );
          },
        ), delay: 500),
        _buildAnimatedCard(_buildFeatureCard(
          icon: Icons.verified_rounded,
          color: Colors.green,
          title: "Verify Attendance",
          subtitle: "Verify student attendance records for transparency",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SupervisorAttendanceVerificationScreen(),
              ),
            );
          },
        ), delay: 550),
        _buildAnimatedCard(_buildFeatureCard(
          icon: Icons.task_alt_rounded,
          color: Colors.purple,
          title: "Review Daily Tasks",
          subtitle: "Approve or reject student daily task submissions",
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const SupervisorDailyTasksReviewScreen(),
              ),
            );
          },
        ), delay: 600),

        const SizedBox(height: 12),
        _buildAnimatedCard(_buildLogoutCard(context), delay: 650),
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

  // --- Statistics Row ---
  Widget _buildStatsRow() {
    if (_isLoadingStudents) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
        child: Column(
          children: [
            LoadingSkeleton(height: 100),
            SizedBox(height: 12),
            LoadingSkeleton(height: 100),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Row(
        children: [
          Expanded(
            child: StatCard(
              title: 'Assigned',
              value: '$_totalAssigned',
              icon: Icons.people_rounded,
              color: AppTheme.supervisorPrimary,
            ),
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: StatCard(
              title: 'Pending Eval',
              value: '$_pendingEvaluations',
              icon: Icons.assignment_rounded,
              color: AppTheme.warningColor,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SupervisorEvaluationFormScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- Student Tile ---
  Widget _buildStudentTile(OjtRecord record) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: StudentInfoTile(
        studentName: record.studentName ?? 'Unknown',
        course: record.companyName,
        company: record.companyName,
        requiredHours: record.requiredHours,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SupervisorStudentMonitorScreen(),
            ),
          );
        },
      ),
    );
  }

  // --- View All Students Card ---
  Widget _buildViewAllStudentsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
      ),
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SupervisorStudentMonitorScreen(),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'View All ${_assignedStudents.length} Students',
                style: AppTheme.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.supervisorPrimary,
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              Icon(
                Icons.arrow_forward,
                color: AppTheme.supervisorPrimary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Profile Header with Gradient & Shadow ---
  Widget _buildProfileHeader() {
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
              fullName.split(" ").where((e) => e.isNotEmpty).map((e) => e[0]).take(2).join(),
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
                  style: AppTheme.primaryButtonStyle(AppTheme.supervisorPrimary),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text("Logout"),
                ),
              ],
            ),
          );

          if (confirm == true) {
            setState(() => _isLoading = true);

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
