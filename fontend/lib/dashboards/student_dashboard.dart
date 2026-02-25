import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/role_dashboard.dart';
import '../widgets/role_guard.dart';
import 'student_checklist_screen.dart';
import 'student_attendance_screen.dart';
import 'student_dtr_view_screen.dart';
import 'student_daily_tasks_screen.dart';
import '../screens/login_screen.dart';
import '../services/attendance_service.dart';
import '../screens/student/student_progress_report_screen.dart';
import '../services/auth_service.dart';
import '../services/ojt_service.dart';
import '../services/prediction_service.dart';
import '../widgets/stat_card.dart';
import '../widgets/section_header.dart';
import '../widgets/loading_skeleton.dart';
import '../core/app_theme.dart';
import '../widgets/error_state_widget.dart';
import '../services/cache_service.dart';

// Conditional import for File operations
import 'file_helper_stub.dart'
    if (dart.library.io) 'file_helper_io.dart' as file_helper;

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard>
    with SingleTickerProviderStateMixin {
  dynamic _attendanceImage; // File on mobile, Uint8List on web
  dynamic _profileImage; // File on mobile, Uint8List on web
  Uint8List? _profileImageBytes;
  bool _isTimedIn = false;
  String? _lastActionTime;
  int _completedHours = 0;
  int _requiredHours = 300;
  final picker = ImagePicker();
  bool _isRefreshing = false;

  int? _studentUserId;
  String? _studentName;
  String? _studentId;
  String? _course;
  String? _coordinator;
  String? _supervisor;

  List<Map<String, dynamic>> _dtrRecords = [];

  // Enhanced status data
  Map<String, dynamic>? _studentStatus;
  bool _statusLoading = false;
  String? _statusError;

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  bool _isLoading = false;
  String? _errorMessage;
  bool _isFromCache = false;

  @override
  void initState() {
    super.initState();
    _initDashboardData();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initDashboardData() async {
    setState(() => _isRefreshing = true);
    try {
      await _loadStudentData();
      await Future.wait([
        _loadAttendanceData(),
        _loadDTRRecords(),
        _loadStudentStatus(),
      ]);
      if (mounted) setState(() {
        _errorMessage = null;
        _isFromCache = false;
      });
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      // Try to serve from cache
      if (_studentUserId != null) {
        final cached = await CacheService.load(
          'student_status_$_studentUserId',
          ignoreTtl: true,
        );
        if (cached != null && mounted) {
          setState(() {
            _studentStatus = cached;
            _errorMessage = null;
            _isFromCache = true;
          });
        } else if (mounted) {
          setState(() => _errorMessage = 'Failed to load dashboard. Check your connection.');
        }
      } else if (mounted) {
        setState(() => _errorMessage = 'Failed to load dashboard. Check your connection.');
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _loadStudentStatus() async {
    if (_studentUserId == null) return;

    setState(() {
      _statusLoading = true;
      _statusError = null;
    });

    try {
      final status = await OjtService.getStudentStatus(_studentUserId!);

      // Persist to cache (TTL: 30 minutes)
      await CacheService.save(
        'student_status_$_studentUserId',
        status,
        ttl: const Duration(minutes: 30),
      );

      if (status['hours'] != null) {
        final hours = status['hours'] as Map<String, dynamic>;
        setState(() {
          _completedHours = _parseInt(hours['completed']) ?? _completedHours;
          _requiredHours = _parseInt(hours['required']) ?? _requiredHours;
        });
      }

      setState(() {
        _studentStatus = status;
        _statusError = null;
      });
    } catch (e) {
      debugPrint('Error loading student status: $e');
      // Fallback: load stale cache
      final cached = await CacheService.load(
        'student_status_$_studentUserId',
        ignoreTtl: true,
      );
      if (cached != null && mounted) {
        setState(() {
          _studentStatus = cached;
          _statusError = null;
          _isFromCache = true;
        });
      } else {
        setState(() => _statusError = 'Unable to load status');
      }
    } finally {
      if (mounted) {
        setState(() {
          _statusLoading = false;
        });
      }
    }
  }

  Future<void> _refreshDashboard() async {
    await _initDashboardData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dashboard refreshed'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  // ------------------- Loaders -------------------
  Future<void> _loadStudentData() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user != null) {
        final imageBytes = _decodeProfilePhoto(user.profilePhoto);
        setState(() {
          _studentUserId = user.userId;
          _studentName = user.fullName;
          _studentId =
              user.studentId ?? (user.userId != null ? '${user.userId}' : 'N/A');
          _course = user.course ?? 'N/A';
          _requiredHours = user.requiredHours ?? _requiredHours;
          _profileImageBytes = imageBytes;
          _profileImage = null;
        });

        if (user.userId != null) {
          try {
            final records =
                await OjtService.getOjtRecords(studentId: user.userId);
            if (records.isNotEmpty) {
              final record = records.first;
              setState(() {
                _coordinator = record.coordinatorName ?? _coordinator;
                _supervisor = record.supervisorName ?? _supervisor;
                if (record.requiredHours != null) {
                  _requiredHours = record.requiredHours!;
                }
              });
            }
          } catch (_) {
            // ignore OJT fetch errors
          }
        }
        return;
      }
    } catch (_) {
      // ignore errors and use local data instead
    }

    await _loadStudentDataFromPrefs();
  }

  Future<void> _loadStudentDataFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    
    final profilePath = prefs.getString('student_photo');
    dynamic profileImg;
    Uint8List? profileImgBytes;
    
    if (!kIsWeb && profilePath != null) {
      try {
        final file = file_helper.createFile(profilePath);
        if (file != null && await file_helper.fileExists(file)) {
          profileImg = file;
          profileImgBytes = null;
        } else {
          profileImg = null;
          profileImgBytes = null;
        }
      } catch (_) {
        profileImg = null;
        profileImgBytes = null;
      }
    } else {
      profileImg = null;
      profileImgBytes = null;
    }
    
    setState(() {
      _studentUserId ??= prefs.getInt('student_user_id');
      _studentName = prefs.getString('student_name') ?? "Unknown";
      _studentId = prefs.getString('student_id') ?? "N/A";
      _course = prefs.getString('student_course') ?? "N/A";
      _coordinator = prefs.getString('student_coordinator') ?? "Pending";
      _supervisor = prefs.getString('student_supervisor') ?? "Pending";
      _requiredHours = prefs.getInt('student_required_hours') ?? _requiredHours;
      _profileImage = profileImg;
      _profileImageBytes = profileImgBytes;
    });
  }

  Future<void> _loadAttendanceData() async {
    int? serverHours;
    if (_studentUserId != null) {
      try {
        final summary =
            await AttendanceService.getAttendanceSummary(_studentUserId!);
        final totalHours = summary['total_hours_completed'];
        if (totalHours is num) {
          serverHours = totalHours.round();
        }
      } catch (_) {
        // ignore summary errors and fall back to cached/local data
      }
    }

    final prefs = await SharedPreferences.getInstance();
    
    // Check if it's a new day and reset attendance image if needed
    final lastImageDate = prefs.getString('last_attendance_image_date');
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    if (lastImageDate != today) {
      // It's a new day - clear the attendance image
      await prefs.remove('attendance_image');
      await prefs.remove('attendance_image_base64');
      await prefs.setString('last_attendance_image_date', today);
    }
    
    final imagePath = prefs.getString('attendance_image');
    final isTimedIn = prefs.getBool('is_timed_in') ?? false;
    final lastTime = prefs.getString('last_action_time');
    final localHours = prefs.getInt('completed_hours');

    // Handle attendance image loading (only if it's from today)
    dynamic attendanceImg;
    if (lastImageDate == today) {
      if (!kIsWeb && imagePath != null) {
        try {
          final file = file_helper.createFile(imagePath);
          if (file != null && await file_helper.fileExists(file)) {
            attendanceImg = file;
          }
        } catch (_) {
          // Ignore file errors
        }
      } else {
        // On web, try to load from base64 if available
        final imageBase64 = prefs.getString('attendance_image_base64');
        if (imageBase64 != null) {
          try {
            attendanceImg = base64Decode(imageBase64);
          } catch (_) {
            // Ignore decode errors
          }
        }
      }
    }

    // Prefer server-approved hours when available; fall back to local cache only if needed
    final resolvedHours = serverHours ?? localHours ?? _completedHours;

    setState(() {
      _isTimedIn = isTimedIn;
      _lastActionTime = lastTime;
      _completedHours = resolvedHours;
      _attendanceImage = attendanceImg;
    });
  }

  Future<void> _loadDTRRecords() async {
    try {
      int? studentId = _studentUserId;
      if (studentId == null) {
        final prefs = await SharedPreferences.getInstance();
        final studentIdStr = prefs.getString('student_id');
        if (studentIdStr != null) {
          studentId = int.tryParse(studentIdStr);
        }
      }

      if (studentId != null) {
        final attendanceList = await AttendanceService.getAttendance(
          studentId: studentId,
        );

        final List<Map<String, dynamic>> dtrList = attendanceList
            .map((attendance) => {
                  'date': attendance.date.toIso8601String().split('T')[0],
                  'amIn': attendance.morningIn ?? '-',
                  'amOut': attendance.morningOut ?? '-',
                  'pmIn': attendance.afternoonIn ?? '-',
                  'pmOut': attendance.afternoonOut ?? '-',
                  'otIn': attendance.overtimeIn ?? '-',
                  'otOut': attendance.overtimeOut ?? '-',
                  'totalHours': attendance.totalHours?.toStringAsFixed(1) ?? '0',
                  'verified': attendance.verified,
                  'verifiedByName': attendance.verifiedByName,
                  'verifiedAt': attendance.verifiedAt?.toIso8601String(),
                  'status': attendance.status ?? 'Pending', // Include status field
                })
            .toList();

        setState(() {
          _dtrRecords = dtrList;
        });
        return;
      }

      // If no student ID, set empty list
      setState(() {
        _dtrRecords = [];
      });
    } catch (e) {
      // On error, set empty list
      setState(() {
        _dtrRecords = [];
      });
    }
  }

  // ------------------- UI -------------------
  @override
  Widget build(BuildContext context) {
    return RoleGuard(
      allowedRoles: const ['student'],
      builder: (ctx, user) => _buildDashboardContent(ctx),
    );
  }

  Widget _buildDashboardContent(BuildContext context) {
    // ✅ Show loading animation if logging out
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/logo.gif', height: 180)
                  .animate()
                  .fadeIn(duration: 900.ms)
                  .scale(duration: 900.ms),
              const SizedBox(height: 25),
            ],
          ),
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: RefreshIndicator(
        onRefresh: _refreshDashboard,
        child: RoleDashboard(
          title: "Student Dashboard",
          color: AppTheme.studentPrimary,
          tasks: const [],
          appBarActions: [
            IconButton(
              icon: _isRefreshing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.refresh),
              onPressed: _isRefreshing ? null : _refreshDashboard,
              tooltip: 'Refresh Dashboard',
            ),
          ],
          customActions: [
            // Profile Header
            _buildAnimatedCard(_buildProfileCard(), delay: 0),
            
            // Notifications/Alerts Section
            if (_studentStatus != null && _studentStatus!['notifications'] != null && 
                (_studentStatus!['notifications'] as List).isNotEmpty) ...[
              _buildAnimatedCard(
                SectionHeader(
                  title: 'Notifications',
                  icon: Icons.notifications_active_rounded,
                ),
                delay: 50,
              ),
              ...(_studentStatus!['notifications'] as List).asMap().entries.map((entry) {
                final delay = 100 + (entry.key * 50);
                return _buildAnimatedCard(
                  _buildNotificationCard(entry.value as Map<String, dynamic>),
                  delay: delay,
                );
              }),
            ],
            
            // Key Metrics Section
            _buildAnimatedCard(
              SectionHeader(
                title: 'OJT Overview',
                icon: Icons.dashboard_rounded,
              ),
              delay: 150,
            ),
            _buildAnimatedCard(_buildQuickStatsRow(), delay: 200),
            
            // Progress Card
            _buildAnimatedCard(
              SectionHeader(
                title: 'Training Progress',
                icon: Icons.auto_graph_rounded,
              ),
              delay: 250,
            ),
            _buildAnimatedCard(_buildHoursProgressCard(), delay: 300),
            
            // AI Insights
            _buildAnimatedCard(
              SectionHeader(
                title: 'AI Smart Insights',
                icon: Icons.psychology_rounded,
              ),
              delay: 350,
            ),
            _buildAnimatedCard(_buildRiskAndInsightsCard(), delay: 400),
            
            // Quick Actions Section
            _buildAnimatedCard(
              SectionHeader(
                title: 'Management Actions',
                icon: Icons.bolt_rounded,
              ),
              delay: 450,
            ),
            _buildAnimatedCard(_buildAttendanceActionCard(), delay: 500),
            const SizedBox(height: 12),
            _buildAnimatedCard(_buildUploadCard(), delay: 550),
            
            if (_attendanceImage != null) ...[
              const SizedBox(height: 12),
              _buildAnimatedCard(_buildLastRecordCard(), delay: 600),
            ],
            
            // More Options
            _buildAnimatedCard(
              SectionHeader(
                title: 'Learning Resources',
                icon: Icons.library_books_rounded,
              ),
              delay: 650,
            ),
            _buildAnimatedCard(_buildImprovementTipsCard(), delay: 700),
            const SizedBox(height: 12),
            _buildAnimatedCard(_buildChecklistCardButton(), delay: 750),
            const SizedBox(height: 12),
            _buildAnimatedCard(_buildDailyTasksCardButton(), delay: 800),
            
            const SizedBox(height: 24),
            _buildAnimatedCard(_buildLogoutCard(), delay: 850),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedCard(Widget child, {int delay = 0}) {
    return Animate(
      effects: [
        FadeEffect(duration: 600.ms, delay: delay.ms),
        SlideEffect(
            begin: const Offset(0, 0.2),
            end: Offset.zero,
            duration: 600.ms,
            delay: delay.ms),
      ],
      child: child,
    );
  }

  // ------------------- Profile Card -------------------
  Widget _buildProfileCard() {
    double progress = (_requiredHours > 0)
        ? ((_completedHours / _requiredHours).clamp(0.0, 1.0))
        : 0.0;

    ImageProvider? profileImageProvider;
    if (!kIsWeb && _profileImage != null) {
      try {
        profileImageProvider = file_helper.createImageProvider(_profileImage);
      } catch (_) {
        if (_profileImageBytes != null) {
          profileImageProvider = MemoryImage(_profileImageBytes!);
        }
      }
    } else if (_profileImageBytes != null) {
      profileImageProvider = MemoryImage(_profileImageBytes!);
    } else if (kIsWeb && _attendanceImage is Uint8List) {
      profileImageProvider = MemoryImage(_attendanceImage as Uint8List);
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.studentPrimary,
            AppTheme.studentPrimary.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: [
          BoxShadow(
            color: AppTheme.studentPrimary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      padding: const EdgeInsets.all(AppTheme.spacing20),
      child: Row(
        children: [
          Hero(
            tag: 'profile-photo',
            child: CircleAvatar(
              radius: 42,
              backgroundImage: profileImageProvider,
              backgroundColor: Colors.white,
              child: profileImageProvider == null
                  ? Icon(
                      Icons.person,
                      size: 42,
                      color: AppTheme.studentPrimary,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: AppTheme.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _studentName ?? "Loading...",
                  style: AppTheme.heading2.copyWith(color: Colors.white),
                ),
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  "ID: ${_studentId ?? 'N/A'}",
                  style: AppTheme.bodyMedium.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: AppTheme.spacing2),
                Text(
                  "Course: ${_course ?? 'N/A'}",
                  style: AppTheme.bodyMedium.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: AppTheme.spacing12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  "$_completedHours / $_requiredHours hours",
                  style: AppTheme.bodySmall.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------- Notification Card -------------------
  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final type = notification['type'] as String? ?? 'info';
    final message = notification['message'] as String? ?? '';
    final priority = notification['priority'] as String? ?? 'medium';

    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (type) {
      case 'error':
        backgroundColor = AppTheme.errorColor.withOpacity(0.1);
        textColor = AppTheme.errorColor;
        icon = Icons.error_outline;
        break;
      case 'warning':
        backgroundColor = AppTheme.warningColor.withOpacity(0.1);
        textColor = AppTheme.warningColor;
        icon = Icons.warning_amber_rounded;
        break;
      case 'success':
        backgroundColor = AppTheme.successColor.withOpacity(0.1);
        textColor = AppTheme.successColor;
        icon = Icons.check_circle_outline;
        break;
      default:
        backgroundColor = AppTheme.infoColor.withOpacity(0.1);
        textColor = AppTheme.infoColor;
        icon = Icons.info_outline;
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
      ),
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      color: backgroundColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing16,
          vertical: AppTheme.spacing12,
        ),
        child: Row(
          children: [
            Icon(icon, color: textColor, size: 24),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Text(
                message,
                style: AppTheme.bodyMedium.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to safely parse numeric values from JSON (handles both string and number)
  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  // ------------------- Risk Level & AI Insights Card -------------------
  Widget _buildRiskAndInsightsCard() {
    if (_statusLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
        child: Column(
          children: [
            LoadingSkeleton(height: 140),
          ],
        ),
      );
    }

    final aiInsight = _studentStatus?['ai_insight'] as Map<String, dynamic>?;
    final riskLevel = aiInsight?['risk_level'] as String?;

    if (riskLevel == null) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        ),
        margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.infoColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                    ),
                    child: Icon(
                      Icons.psychology,
                      color: AppTheme.infoColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Expanded(
                    child: Text(
                      'AI Risk Assessment',
                      style: AppTheme.heading3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing12),
              Text(
                _statusError ?? 'Risk assessment will be available after your first evaluation.',
                style: AppTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }

    final topReasons = aiInsight?['top_reasons'] as List<dynamic>? ?? [];
    final recommendation = aiInsight?['recommendation'] as String?;
    // Map risk level to progress band for student-facing display (no HIGH/MEDIUM/LOW risk label)
    final progressPct = riskLevel == 'LOW'
        ? 80
        : riskLevel == 'MEDIUM'
            ? 70
            : 50; // HIGH or unknown
    final statusLabel = progressPct >= 80
        ? 'On Track'
        : progressPct >= 60
            ? 'Needs Attention'
            : 'Needs Attention';
    final statusColor = progressPct >= 80
        ? AppTheme.successColor
        : progressPct >= 60
            ? AppTheme.warningColor
            : AppTheme.warningColor;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
      ),
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                  ),
                  child: Icon(
                    Icons.trending_up,
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Text(
                    'Progress & AI Insight',
                    style: AppTheme.heading3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing12),
            Row(
              children: [
                Text(
                  '${progressPct}%',
                  style: AppTheme.heading3.copyWith(color: statusColor),
                ),
                const SizedBox(width: AppTheme.spacing8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing8,
                    vertical: AppTheme.spacing4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                  ),
                  child: Text(
                    statusLabel,
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            if (topReasons.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacing12),
              Text(
                'Key factors:',
                style: AppTheme.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTheme.spacing4),
              ...topReasons.take(3).map((reason) => Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.spacing4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ',
                          style: AppTheme.bodyMedium.copyWith(
                            color: Colors.grey[700],
                          ),
                        ),
                        Expanded(
                          child: Text(
                            reason.toString(),
                            style: AppTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
            if (recommendation != null && recommendation.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacing12),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing12),
                decoration: BoxDecoration(
                  color: AppTheme.infoColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                  border: Border.all(
                    color: AppTheme.infoColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: AppTheme.infoColor,
                      size: 20,
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                    Expanded(
                      child: Text(
                        recommendation,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.infoColor.withOpacity(0.9),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ------------------- Hours Progress Card (Enhanced) -------------------
  Widget _buildHoursProgressCard() {
    final hours = _studentStatus?['hours'] as Map<String, dynamic>?;
    final completed = _parseInt(hours?['completed']) ?? _completedHours;
    final required = _parseInt(hours?['required']) ?? _requiredHours;
    final remaining = _parseInt(hours?['remaining']) ?? (required - completed);
    final progress = _parseInt(hours?['progress_percentage']) ??
        (required > 0 ? ((completed / required) * 100).round() : 0);

    Color progressColor = AppTheme.studentPrimary;
    if (progress >= 90) {
      progressColor = AppTheme.successColor;
    } else if (progress < 50) {
      progressColor = AppTheme.warningColor;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
      ),
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: progressColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                  ),
                  child: Icon(
                    Icons.trending_up,
                    color: progressColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Text(
                    'OJT Hours Progress',
                    style: AppTheme.heading3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$completed',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: progressColor,
                      ),
                    ),
                    Text(
                      'of $required hours',
                      style: AppTheme.bodySmall,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$progress%',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: progressColor,
                      ),
                    ),
                    Text(
                      'Complete',
                      style: AppTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing16),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
              child: LinearProgressIndicator(
                value: progress / 100,
                minHeight: 10,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$remaining hours remaining',
                  style: AppTheme.bodySmall,
                ),
                if (remaining > 0)
                  Text(
                    '~${(remaining / 8).ceil()} days at 8hrs/day',
                    style: AppTheme.bodySmall.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ------------------- Quick Stats Row -------------------
  Widget _buildQuickStatsRow() {
    final attendance = _studentStatus?['attendance'] as Map<String, dynamic>?;
    final daysPresent = _parseInt(attendance?['days_present']) ?? 0;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Row(
        children: [
          Expanded(
            child: StatCard(
              title: 'Days Present',
              value: '$daysPresent',
              icon: Icons.calendar_today,
              color: AppTheme.infoColor,
            ),
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: StatCard(
              title: 'Remaining',
              value: '${_requiredHours - _completedHours}',
              subtitle: 'hours',
              icon: Icons.timer_outlined,
              color: AppTheme.warningColor,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------- Attendance Action Card -------------------
  Widget _buildAttendanceActionCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
      ),
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.studentPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                  ),
                  child: Icon(
                    Icons.access_time,
                    color: AppTheme.studentPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Attendance',
                        style: AppTheme.heading3,
                      ),
                      if (_lastActionTime != null)
                        Text(
                          'Last: $_lastActionTime',
                          style: AppTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showAttendanceOptions(context),
                    icon: const Icon(Icons.login),
                    label: const Text('Time In/Out'),
                    style: AppTheme.primaryButtonStyle(AppTheme.studentPrimary),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StudentDTRViewScreen(
                            studentName: _studentName ?? "Unknown",
                            studentId: _studentId ?? "N/A",
                            course: _course ?? "N/A",
                            dtrRecords: _dtrRecords,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.list_alt),
                    label: const Text('View DTR'),
                    style: AppTheme.secondaryButtonStyle(AppTheme.studentPrimary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ------------------- Attendance Card (Legacy - kept for compatibility) -------------------
  Widget _buildAttendanceCard() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Image.network(
          'https://cdn-icons-png.flaticon.com/512/3515/3515523.png',
          height: 30,
        ),
        title: const Text(
          "Attendance Record",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text("View or update your daily attendance records"),
        trailing: Image.network(
          'https://cdn-icons-png.flaticon.com/512/271/271228.png',
          height: 20,
        ),
        onTap: () => _showAttendanceOptions(context),
      ),
    );
  }

  // ------------------- Last Attendance Record -------------------
  Widget _buildLastRecordCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
      ),
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.infoColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                  ),
                  child: Icon(
                    Icons.history,
                    color: AppTheme.infoColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Text(
                  "Last Attendance Record",
                  style: AppTheme.heading3,
                ),
              ],
            ),
            if (_lastActionTime != null) ...[
              const SizedBox(height: AppTheme.spacing12),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 18,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  Text(
                    _lastActionTime!,
                    style: AppTheme.bodyMedium,
                  ),
                ],
              ),
            ],
            if (_attendanceImage != null) ...[
              const SizedBox(height: AppTheme.spacing12),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                child: _buildAttendanceImage()
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .scale(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceImage() {
    if (kIsWeb && _attendanceImage is Uint8List) {
      return Image.memory(
        _attendanceImage as Uint8List,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
      );
    } else if (!kIsWeb && _attendanceImage != null) {
      try {
        return Image(
          image: file_helper.createImageProvider(_attendanceImage)!,
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
        );
      } catch (_) {
        return const SizedBox(height: 200);
      }
    }
    return const SizedBox(height: 200);
  }

  // ------------------- Upload Report -------------------
  Widget _buildUploadCard() {
    return _buildCardTemplate(
      icon: Icons.upload_file,
      title: "Upload Progress Report",
      subtitle: "Submit your daily report after duty ends",
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const StudentProgressReportScreen(),
          ),
        );
      },
    );
  }

  // ------------------- Shared Card Template -------------------
  Widget _buildCardTemplate({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    final color = iconColor ?? AppTheme.studentPrimary;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
      ),
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: AppTheme.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing4),
                    Text(
                      subtitle,
                      style: AppTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.grey[400],
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------- Improvement Tips -------------------
  Widget _buildImprovementTipsCard() {
    return _buildCardTemplate(
      icon: Icons.lightbulb_outline,
      title: "Get Improvement Tips",
      subtitle: "Receive suggestions to improve your OJT performance",
      iconColor: AppTheme.warningColor,
      onTap: () {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
            ),
            title: const Text("🌟 OJT Improvement Tips"),
            content: const Text("💡 Keep improving daily with good habits!"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Close"),
              ),
            ],
          ),
        );
      },
    );
  }

  // ------------------- Checklist -------------------
  Widget _buildChecklistCardButton() {
    return _buildCardTemplate(
      icon: Icons.checklist,
      title: "OJT Application Checklist",
      subtitle: "View and upload required OJT documents",
      iconColor: AppTheme.infoColor,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const StudentChecklistScreen(),
          ),
        );
      },
    );
  }

  // ------------------- Daily Tasks & Competencies -------------------
  Widget _buildDailyTasksCardButton() {
    return _buildCardTemplate(
      icon: Icons.task_alt,
      title: "Daily Tasks & Competencies",
      subtitle: "Log your daily tasks and track competency progress",
      iconColor: AppTheme.studentPrimary,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const StudentDailyTasksScreen(),
          ),
        );
      },
    );
  }

  // ------------------- Logout Logic -------------------
  Widget _buildLogoutCard() {
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
                  "Are you sure you want to log out?"),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: AppTheme.primaryButtonStyle(AppTheme.studentPrimary),
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
                      "Securely sign out of your account",
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

  void _showAttendanceOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.borderRadiusLarge),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.studentPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    color: AppTheme.studentPrimary,
                  ),
                ),
                title: const Text("Record Attendance"),
                subtitle: const Text("Open camera to take attendance photo"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StudentAttendanceScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.infoColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.calendar_today,
                    color: AppTheme.infoColor,
                  ),
                ),
                title: const Text("View DTR"),
                subtitle: const Text("Check your Daily Time Record"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StudentDTRViewScreen(
                        studentName: _studentName ?? "Unknown",
                        studentId: _studentId ?? "N/A",
                        course: _course ?? "N/A",
                        dtrRecords: _dtrRecords,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Uint8List? _decodeProfilePhoto(String? photo) {
    if (photo == null || photo.isEmpty) return null;
    try {
      final sanitized =
          photo.contains(',') ? photo.split(',').last.trim() : photo.trim();
      return base64Decode(sanitized);
    } catch (_) {
      return null;
    }
  }

}
