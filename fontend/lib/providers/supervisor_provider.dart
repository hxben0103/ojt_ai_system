import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/ojt_service.dart';
import '../services/cache_service.dart';
import '../models/ojt_record.dart';
import '../models/attendance.dart';

/// Manages all data for the Supervisor Dashboard.
class SupervisorProvider extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────────────
  bool isLoading         = true;
  bool isLoadingStudents = true;
  bool isFromCache       = false;
  String? errorMessage;

  // Profile
  String fullName = 'Loading...';
  String idNumber = 'N/A';
  String office   = 'N/A';
  String position = 'Industry Supervisor';
  Uint8List? profileImageBytes;

  // Students & Stats
  List<OjtRecord> assignedStudents = [];
  int totalAssigned        = 0;
  int pendingEvaluations   = 0;
  int highRiskStudents     = 0;
  int mediumRiskStudents   = 0;
  double averageForecastedGrade = 0.0;
  Map<int, Attendance> todayAttendanceMap = {};

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> loadAll() async {
    isLoading         = true;
    isLoadingStudents = true;
    isFromCache       = false;
    errorMessage      = null;
    notifyListeners();

    await Future.wait([_loadProfile(), _loadAssignedStudents()]);
  }

  Future<void> refresh() => loadAll();

  // ── Private helpers ────────────────────────────────────────────────────────

  Uint8List? _decodeProfilePhoto(String? photoBase64) {
    if (photoBase64 == null || photoBase64.isEmpty) return null;
    try {
      String base64Data = photoBase64;
      if (photoBase64.contains(',')) {
        base64Data = photoBase64.split(',').last;
      }
      return base64Decode(base64Data);
    } catch (e) {
      debugPrint('Error decoding profile photo: $e');
      return null;
    }
  }

  Future<void> _loadProfile() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user != null) {
        fullName = user.fullName;
        idNumber = user.userId?.toString() ?? user.email;
        office   = user.course ?? 'N/A';
        position = user.role;
        profileImageBytes = _decodeProfilePhoto(user.profilePhoto);
      }
    } catch (_) {
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadAssignedStudents() async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser?.userId == null) {
        isLoadingStudents = false;
        notifyListeners();
        return;
      }

      final supervisorId = currentUser!.userId!;
      
      // Use the optimized aggregated endpoint
      final overview = await OjtService.getSupervisorOverview(supervisorId);
      
      final List<dynamic> studentsData = overview['students'] ?? [];
      final List<dynamic> attendanceData = overview['attendance'] ?? [];

      List<OjtRecord> records = [];
      int pendingCount = 0;
      int highRisk = 0;
      int mediumRisk = 0;
      double totalGrade = 0.0;
      int gradedCount = 0;

      for (var s in studentsData) {
        // Process AI Insights first to get risk for the record
        String? currentRisk;
        final aiInsight = s['latest_ai_insight'];
        if (aiInsight != null) {
          final Map<String, dynamic> result = Map<String, dynamic>.from(aiInsight);
          currentRisk = (result['risk_level'] ?? 
                        result['class_label'] ?? 
                        (result['ai_prediction']?['ml_prediction']?['risk_level']))?.toString().toUpperCase();
          
          if (currentRisk == 'HIGH') {
            highRisk++;
          } else if (currentRisk == 'MEDIUM') {
            mediumRisk++;
          }

          final grade = result['grading']?['forecasted_grade'] ?? result['forecasted_grade'];
          if (grade != null) {
            totalGrade += (grade as num).toDouble();
            gradedCount++;
          }
        }

        // Parse basic record and include the risk level
        final Map<String, dynamic> recordMap = Map<String, dynamic>.from(s);
        recordMap['risk_level'] = currentRisk;
        final record = OjtRecord.fromJson(recordMap);
        records.add(record);

        // Check evaluation status
        final latestEval = s['latest_evaluation'];
        if (latestEval == null || (latestEval['status'] ?? '').toString().toLowerCase() != 'completed') {
          pendingCount++;
        }
      }

      // Map today's attendance
      final Map<int, Attendance> todayMap = {};
      for (var a in attendanceData) {
        final id = a['student_id'];
        if (id != null) {
          todayMap[id as int] = Attendance.fromJson(a);
        }
      }

      // Persist Summary to Cache (TTL: 20 min)
      await CacheService.save(
        'supervisor_students_$supervisorId',
        {
          'total': records.length, 
          'pending_evaluations': pendingCount,
          'high_risk': highRisk,
          'medium_risk': mediumRisk,
        },
        ttl: const Duration(minutes: 20),
      );

      assignedStudents = records;
      totalAssigned = records.length;
      pendingEvaluations = pendingCount;
      highRiskStudents = highRisk;
      mediumRiskStudents = mediumRisk;
      averageForecastedGrade = gradedCount > 0 ? (totalGrade / gradedCount) : 0.0;
      todayAttendanceMap = todayMap;
      isFromCache = false;
      errorMessage = null;

    } catch (e) {
      debugPrint('[SupervisorProvider] error: $e');
      final user = await AuthService.getCurrentUser();
      final cached = user?.userId != null
          ? await CacheService.load('supervisor_students_${user!.userId}', ignoreTtl: true)
          : null;

      if (cached != null) {
        totalAssigned = (cached['total'] as int?) ?? 0;
        pendingEvaluations = (cached['pending_evaluations'] as int?) ?? 0;
        highRiskStudents = (cached['high_risk'] as int?) ?? 0;
        mediumRiskStudents = (cached['medium_risk'] as int?) ?? 0;
        averageForecastedGrade = 0.0;
        isFromCache = true;
        errorMessage = null;
      } else {
        assignedStudents = [];
        totalAssigned = 0;
        pendingEvaluations = 0;
        highRiskStudents = 0;
        mediumRiskStudents = 0;
        averageForecastedGrade = 0.0;
        errorMessage = 'Failed to load supervisor data. Review server logs.';
      }
    } finally {
      isLoadingStudents = false;
      notifyListeners();
    }
  }
}

