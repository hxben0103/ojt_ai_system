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
import '../widgets/insight_card.dart';
import '../widgets/integrity_badge.dart';
import '../widgets/progress_summary_card.dart';
import '../widgets/ojt_progress_hero_card.dart';
import '../widgets/ojt_progress_hero_card.dart';
import '../widgets/explainable_ai_card.dart';
import '../widgets/weekly_ai_summary_card.dart';
import '../widgets/trust_score_badge.dart';
import '../widgets/performance_trend_indicator.dart';

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
      final rawStatus = await OjtService.getStudentStatus(_studentUserId!);
      final status = Map<String, dynamic>.from(rawStatus);

      // Persist to cache (TTL: 30 minutes)
      await CacheService.save(
        'student_status_$_studentUserId',
        status,
        ttl: const Duration(minutes: 30),
      );

      if (status['hours'] != null) {
        final hours = Map<String, dynamic>.from(status['hours'] as Map);
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
            // Ensure status logic allows OJT actions, otherwise block operational widgets
            if (_studentStatus != null && _studentStatus?['can_perform_ojt_actions'] == false) ...[
              _buildAnimatedCard(_buildOjtSetupIncompleteCard(), delay: 0),
              const SizedBox(height: AppTheme.spacing24),
            ],

            if (_studentStatus == null || _studentStatus?['can_perform_ojt_actions'] != false) ...[
              // ── 1. Hero Performance Card (Progress Summary) ──
              _buildAnimatedCard(_buildHeroPerformanceCard(), delay: 0),
              const SizedBox(height: AppTheme.spacing16),
  
              // ── 2. Why this score? (Explainable AI Panel) ──
              _buildAnimatedCard(_buildExplainableAiPanel(), delay: 40),
              const SizedBox(height: AppTheme.spacing16),
  
              // ── 3. Weekly AI Summary ──
              _buildAnimatedCard(_buildWeeklyAiSummary(), delay: 60),
              const SizedBox(height: AppTheme.spacing16),
  
              // ── 4. Attendance Integrity Badge ──
              _buildAnimatedCard(_buildAttendanceIntegritySection(), delay: 80),
              const SizedBox(height: AppTheme.spacing24),
  
              // ── 5. Compact OJT Hours Card ──
              _buildAnimatedCard(_buildCompactHoursCard(), delay: 140),
              const SizedBox(height: AppTheme.spacing24),
  
              // ── 6. Condensed Action Row (Time In/Out + View DTR) ──
              _buildAnimatedCard(_buildCondensedActionRow(), delay: 200),
              const SizedBox(height: AppTheme.spacing24),
  
              // ── 7. Last attendance record ──
              if (_attendanceImage != null) ...[
                _buildAnimatedCard(_buildLastRecordCard(), delay: 260),
                const SizedBox(height: AppTheme.spacing24),
              ],
            ],

            // ── 8. Learning Resources (Always visible, but internal links may be gated) ──
            _buildAnimatedCard(_buildLearningResourcesCard(), delay: 320),
            
            const SizedBox(height: AppTheme.spacing32),
            _buildAnimatedCard(_buildLogoutCard(), delay: 380),
            const SizedBox(height: AppTheme.spacing48),
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

  // ── 0. OJT Setup Incomplete Card ──
  Widget _buildOjtSetupIncompleteCard() {
    final reason = _studentStatus?['blocking_reason'] ?? 'Your OJT setup is incomplete.';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      padding: const EdgeInsets.all(AppTheme.spacing20),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(color: AppTheme.warningColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_person_rounded, color: AppTheme.warningColor, size: 28),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Text(
                  'Access Restricted',
                  style: AppTheme.heading3.copyWith(color: AppTheme.warningColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
          Text(
            reason,
            style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            'You must have an active OJT Record assigned to both a Coordinator and a Supervisor to track attendance, hours, and daily tasks.',
            style: AppTheme.bodySmall.copyWith(color: Colors.grey[700], height: 1.4),
          ),
          const SizedBox(height: AppTheme.spacing16),
          FilledButton.icon(
            onPressed: () {
               Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentChecklistScreen()));
            },
            icon: const Icon(Icons.checklist_rounded, size: 18),
            label: const Text('View Application Checklist'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
            ),
          )
        ],
      ),
    );
  }

  // ── 1. Hero Performance Card ──
  Widget _buildHeroPerformanceCard() {
    // Profile image provider
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
    }

    // AI insight data
    final aiInsight = _studentStatus?['ai_insight'] != null 
        ? Map<String, dynamic>.from(_studentStatus!['ai_insight'] as Map)
        : null;
    final mlMap = aiInsight?['ml_prediction'] != null 
        ? Map<String, dynamic>.from(aiInsight!['ml_prediction'] as Map)
        : null;
    final riskLevel = (mlMap?['risk_level'] as String? ?? 'LOW').toUpperCase();
    final topReasons = (mlMap?['top_reasons'] as List?)?.cast<String>() ?? [];
    final recommendation = aiInsight?['recommendation'] as String? ?? mlMap?['recommendation'] as String?;
    
    final gradingMap = aiInsight?['grading'] != null 
        ? Map<String, dynamic>.from(aiInsight!['grading'] as Map)
        : null;
    final forecastedGrade = (gradingMap?['forecasted_grade'] as num?)?.toDouble();
    
    final integrityMap = aiInsight?['integrity'] != null 
        ? Map<String, dynamic>.from(aiInsight!['integrity'] as Map)
        : null;
    final integrityScore = (integrityMap?['integrity_score'] as num?)?.toDouble();

    final hoursMap = _studentStatus?['hours'] != null 
        ? Map<String, dynamic>.from(_studentStatus!['hours'] as Map)
        : null;
    final int completedHours = (hoursMap?['completed'] as num?)?.toInt() ?? 0;
    final int requiredHours = (hoursMap?['required'] as num?)?.toInt() ?? 300;
    
    // Dynamic Score = (Completed / Required) * 100
    int computedPct = requiredHours > 0 
        ? ((completedHours / requiredHours) * 100).clamp(0, 100).toInt() 
        : 0;

    // Use ML Progress Score if available, otherwise computed fallback
    final int progressPct = (aiInsight?['score'] as num?)?.toInt() ?? computedPct;

    final String statusLabel;
    final Color statusColor;
    
    // Set color/label dynamically based on actual progress instead of hardcoded risk
    if (progressPct >= 80 || riskLevel == 'LOW') {
      statusLabel = 'On Track';
      statusColor = AppTheme.successColor;
    } else if (progressPct >= 50 || riskLevel == 'MEDIUM') {
      statusLabel = 'Needs Attention';
      statusColor = AppTheme.warningColor;
    } else {
      statusLabel = 'Critical Attention';
      statusColor = AppTheme.errorColor;
    }

    final aiPrediction = aiInsight?['ai_prediction'] != null 
        ? Map<String, dynamic>.from(aiInsight!['ai_prediction'] as Map)
        : null;
    String trendDirection = 'Stable';
    String trendReason = 'Consistent performance';
    if (aiPrediction != null && aiPrediction['trend'] != null) {
      final trend = Map<String, dynamic>.from(aiPrediction['trend'] as Map);
      trendDirection = trend['status'] ?? 'Stable';
      trendReason = trend['reason'] ?? 'Consistent performance';
    } else {
       // fallback inferred trend
       if (progressPct >= 80) { trendDirection = 'Improving'; trendReason = 'Progressing strongly'; }
       else if (progressPct >= 50) { trendDirection = 'Stable'; trendReason = 'Meeting expectations'; }
       else { trendDirection = 'Declining'; trendReason = 'Hours tracking behind schedule'; }
    }

    final double progressFrac = progressPct / 100;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: const [AppTheme.cardShadow],
      ),
      child: _statusLoading
          ? const SizedBox(height: 140, child: Center(child: CircularProgressIndicator()))
          : Column(
              children: [
                // Top row: avatar + identity + circular progress
                Row(
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 32,
                      backgroundImage: profileImageProvider,
                      backgroundColor: AppTheme.studentPrimary.withOpacity(0.1),
                      child: profileImageProvider == null
                          ? Icon(Icons.person_rounded, size: 32, color: AppTheme.studentPrimary)
                          : null,
                    ),
                    const SizedBox(width: AppTheme.spacing12),

                    // Name + ID + course
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _studentName ?? "Loading...",
                            style: AppTheme.heading3.copyWith(height: 1.2),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${_studentId ?? 'N/A'} · ${_course ?? 'N/A'}",
                            style: AppTheme.bodySmall.copyWith(color: Colors.grey[600]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing12),

                    // Circular AI progress
                    SizedBox(
                      width: 76,
                      height: 76,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: progressFrac,
                            strokeWidth: 7,
                            backgroundColor: statusColor.withOpacity(0.08),
                            valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                            strokeCap: StrokeCap.round,
                          ),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$progressPct%',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: statusColor,
                                    height: 1.1,
                                  ),
                                ),
                                Text(
                                  statusLabel.split(' ').first, // Just "On" or "Needs"
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 7,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey[500],
                                    height: 1.1,
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
                
                // Add AI Metrics Row Right Below the Avatar Profile
                if (forecastedGrade != null || integrityScore != null) ...[
                  const SizedBox(height: AppTheme.spacing16),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.studentPrimary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.studentPrimary.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (forecastedGrade != null)
                           Expanded(
                             child: Column(
                               children: [
                                 Row(
                                   mainAxisAlignment: MainAxisAlignment.center,
                                   children: [
                                     Icon(Icons.school_outlined, size: 16, color: AppTheme.studentPrimary),
                                     const SizedBox(width: 6),
                                     Text('Forecasted Grade', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                                   ]
                                 ),
                                 const SizedBox(height: 4),
                                 Text('${forecastedGrade.toStringAsFixed(1)} / 100', style: TextStyle(fontSize: 18, color: AppTheme.studentPrimary, fontWeight: FontWeight.bold)),
                               ],
                             )
                           ),
                        if (forecastedGrade != null && integrityScore != null) 
                          Container(width: 1, height: 30, color: Colors.grey.shade300),
                        if (integrityScore != null)
                           Expanded(
                             child: Column(
                               children: [
                                 Row(
                                   mainAxisAlignment: MainAxisAlignment.center,
                                   children: [
                                     Icon(Icons.verified_user_outlined, size: 16, color: integrityScore >= 80 ? Colors.green : Colors.orange),
                                     const SizedBox(width: 6),
                                     Text('Integrity Score', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                                   ]
                                 ),
                                 const SizedBox(height: 4),
                                 Text('${integrityScore.toInt()} / 100', style: TextStyle(fontSize: 18, color: integrityScore >= 80 ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
                               ],
                             )
                           ),
                      ]
                    )
                  )
                ],

                const SizedBox(height: AppTheme.spacing12),
                PerformanceTrendIndicator(
                  progressScore: progressPct,
                  trendDirection: trendDirection,
                  trendReason: trendReason,
                ),

                // AI status error banner
                if (_statusError != null) ...[
                  const SizedBox(height: AppTheme.spacing8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing12,
                      vertical: AppTheme.spacing8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 16, color: AppTheme.warningColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'AI insights unavailable — tap refresh to retry.',
                            style: AppTheme.bodySmall.copyWith(color: AppTheme.warningColor),
                          ),
                        ),
                        GestureDetector(
                          onTap: _refreshDashboard,
                          child: Text(
                            'Retry',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.warningColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // AI insight bullets (up to 2)
                if (topReasons.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spacing12),
                  const Divider(height: 1),
                  const SizedBox(height: AppTheme.spacing8),
                  ...topReasons.take(2).map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.circle, size: 5, color: statusColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(r, style: AppTheme.bodySmall.copyWith(color: Colors.grey[700])),
                            ),
                          ],
                        ),
                      )),
                ],

                // Recommendation chip
                if (recommendation != null && recommendation.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spacing8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.infoColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb_outline, size: 14, color: AppTheme.infoColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            recommendation,
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.infoColor,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // No AI data yet
                if (topReasons.isEmpty && _statusError == null && !_statusLoading)
                  Padding(
                    padding: const EdgeInsets.only(top: AppTheme.spacing8),
                    child: Text(
                      'AI insights will appear after your first evaluation.',
                      textAlign: TextAlign.center,
                      style: AppTheme.bodySmall.copyWith(color: Colors.grey[500], fontStyle: FontStyle.italic),
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

  // ── AI Performance Insight Hero Card (Student-facing, no risk label) ──
  Widget _buildRiskAndInsightsCard() {
    if (_statusLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
        child: LoadingSkeleton(height: 180),
      );
    }

    Map<String, dynamic>? aiInsight = _studentStatus?['ai_insight'] as Map<String, dynamic>?;
    
    // Inject a computed fallback score just for the UI if API didn't provide one
    if (aiInsight != null && !aiInsight.containsKey('score')) {
      final hoursMap = _studentStatus?['hours'] as Map<String, dynamic>?;
      final int completedHours = (hoursMap?['completed'] as num?)?.toInt() ?? 0;
      final int requiredHours = (hoursMap?['required'] as num?)?.toInt() ?? 300;
      int computedPct = requiredHours > 0 
          ? ((completedHours / requiredHours) * 100).clamp(0, 100).toInt() 
          : 0;
      
      // Use spread operator to safely add to a potentially read-only map
      aiInsight = {...aiInsight, 'computed_pct': computedPct};
    }

    // If there's no insight yet, use isLoading to show loading state
    return OjtProgressHeroCard.fromAiInsight(
      aiInsight: aiInsight,
      isLoading: false,
    );
  }

  // ── Explainable AI Panel ──
  Widget _buildExplainableAiPanel() {
    final aiInsight = _studentStatus?['ai_insight'] as Map<String, dynamic>?;
    final topReasons = (aiInsight?['top_reasons'] as List?)?.cast<String>() ?? [];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: ExplainableAiCard(
        prediction: aiInsight != null ? (aiInsight['ai_prediction'] ?? aiInsight) : {},
        isExpanded: true,
      ),
    );
  }

  // ── Weekly AI Summary ──
  Widget _buildWeeklyAiSummary() {
    final aiInsight = _studentStatus?['ai_insight'] as Map<String, dynamic>?;
    // Missing insight data implies we shouldn't show the summary block
    if (aiInsight == null) return const SizedBox.shrink();

    final recommendation = aiInsight['recommendation'] as String? ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: WeeklyAiSummaryCard(
        studentStatus: _studentStatus,
        recommendation: recommendation,
      ),
    );
  }

  // ── Attendance Integrity Section ──
  Widget _buildAttendanceIntegritySection() {
    final aiInsight = _studentStatus?['ai_insight'] as Map<String, dynamic>?;
    final integrityMap = aiInsight?['integrity'] as Map<String, dynamic>?;
    
    // Pass null if missing so the badge shows "Unavailable" safely
    final int? integrityScore;
    if (integrityMap != null && integrityMap.containsKey('integrity_score') && integrityMap['integrity_score'] != null) {
      integrityScore = (integrityMap['integrity_score'] as num).toInt();
    } else {
      integrityScore = null;
    }
    
    final trustFlags = (integrityMap?['flags'] as List?)?.cast<String>() ?? [];

    final attendanceSummary = _studentStatus?['attendance'] as Map<String, dynamic>?;
    final insideGeofence = (attendanceSummary?['inside_geofence'] as bool?) ?? true;

    // Check if any record has attendance image as a proxy for photo verification
    final photoVerified = _attendanceImage != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: TrustScoreBadge(
        trustScore: integrityScore,
        trustFlags: trustFlags,
        insideGeofence: insideGeofence,
        photoPresent: photoVerified,
      ),
    );
  }

  // ── 4. Compact OJT Hours Card ──
  Widget _buildCompactHoursCard() {
    final hours = _studentStatus?['hours'] as Map<String, dynamic>?;
    final int completed = _parseInt(hours?['completed']) ?? _completedHours;
    final int required = _parseInt(hours?['required']) ?? _requiredHours;
    final int remaining = _parseInt(hours?['remaining']) ?? (required - completed);
    
    return ProgressSummaryCard(
      completedHours: completed,
      requiredHours: required,
      estimatedCompletion: remaining > 0 ? "~${(remaining / 8).ceil()} days" : "Completed",
    );
  }

  // ── 3. Condensed Action Row (Time In/Out + View DTR) ──
  Widget _buildCondensedActionRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _showAttendanceOptions(context),
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Time In / Out'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.studentPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StudentDTRViewScreen(
                      studentName: _studentName ?? "Unknown",
                      studentId: _studentId ?? "N/A",
                      course: _course ?? "N/A",
                      dtrRecords: _dtrRecords,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.list_alt_rounded, size: 18),
              label: const Text('View DTR'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                foregroundColor: AppTheme.studentPrimary,
                side: BorderSide(color: AppTheme.studentPrimary, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 6. Learning Resources — grouped card with list tiles ──
  Widget _buildLearningResourcesCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: const [AppTheme.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing16, AppTheme.spacing12, AppTheme.spacing16, 0),
            child: Text(
              'Learning Resources',
              style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          _resourceListTile(
            icon: Icons.upload_file_rounded,
            color: AppTheme.studentPrimary,
            title: 'Upload Progress Report',
            subtitle: 'Submit your daily report after duty ends',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StudentProgressReportScreen()),
            ),
          ),
          const Divider(height: 1, indent: 56, endIndent: 16),
          _resourceListTile(
            icon: Icons.lightbulb_outline_rounded,
            color: AppTheme.warningColor,
            title: 'Get Improvement Tips',
            subtitle: 'AI-generated suggestions to improve your OJT',
            onTap: () => showDialog(
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
            ),
          ),
          const Divider(height: 1, indent: 56, endIndent: 16),
          _resourceListTile(
            icon: Icons.checklist_rounded,
            color: AppTheme.infoColor,
            title: 'OJT Checklist',
            subtitle: 'View and upload required OJT documents',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StudentChecklistScreen()),
            ),
          ),
          const Divider(height: 1, indent: 56, endIndent: 16),
          _resourceListTile(
            icon: Icons.task_alt_rounded,
            color: AppTheme.studentPrimary,
            title: 'Daily Tasks & Competencies',
            subtitle: 'Log tasks and track competency progress',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StudentDailyTasksScreen()),
            ),
            last: true,
          ),
        ],
      ),
    );
  }

  Widget _resourceListTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool last = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: last
          ? const BorderRadius.vertical(bottom: Radius.circular(AppTheme.borderRadiusLarge))
          : BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing16,
          vertical: AppTheme.spacing12,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                  Text(subtitle, style: AppTheme.bodySmall.copyWith(color: Colors.grey[600])),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey[400]),
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
