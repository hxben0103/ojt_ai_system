import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/ojt_service.dart';
import '../services/analytics_service.dart';
import '../services/cache_service.dart';

/// Manages all data for the Coordinator Dashboard.
class CoordinatorProvider extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────────────
  bool isLoadingProfile = true;
  bool isLoadingStats   = true;
  bool isFromCache      = false;
  String? errorMessage;

  // Profile
  String fullName  = 'Loading...';
  String idNumber  = 'N/A';
  String office    = 'N/A';
  String position  = 'OJT Coordinator';

  // Stats
  int totalStudents         = 0;
  int highRiskStudents      = 0;
  int mediumRiskStudents    = 0;
  int lowRiskStudents       = 0;
  int completedOjt          = 0;
  int activeOjt             = 0;
  double avgCompletionRatio = 0;
  double avgAttendanceRate  = 0;
  String? mostCommonCompetency;

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> loadAll() async {
    isLoadingProfile = true;
    isLoadingStats   = true;
    isFromCache      = false;
    errorMessage     = null;
    notifyListeners();

    await Future.wait([_loadProfile(), _loadStats()]);
  }

  Future<void> refresh() => loadAll();

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<void> _loadProfile() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user != null) {
        fullName = user.fullName;
        idNumber = user.studentId ?? user.email;
        office   = user.course ?? 'OJT Office';
        position = user.role;
      }
    } catch (_) {
    } finally {
      isLoadingProfile = false;
      notifyListeners();
    }
  }

  Future<void> _loadStats() async {
    try {
      final currentUser = await AuthService.getCurrentUser();
      if (currentUser?.userId == null) {
        isLoadingStats = false;
        notifyListeners();
        return;
      }

      final ojtRecords = await OjtService.getOjtRecords(
        coordinatorId: currentUser!.userId,
      );

      int total     = ojtRecords.length;
      int completed = 0;
      int active    = 0;
      for (final r in ojtRecords) {
        if (r.status == 'Completed') completed++;
        else if (r.status == 'Active' || r.status == 'Ongoing') active++;
      }

      Map<String, dynamic> overview = {};
      try {
        overview = await AnalyticsService.getCoordinatorOverview();
      } catch (_) {}

      double avgComp = 0;
      double avgAtt  = 0;
      if (overview.isNotEmpty) {
        final att = overview['attendance_summary'] as Map<String, dynamic>?;
        if (att != null) {
          avgComp = (att['average_completion_ratio'] as num?)?.toDouble() ?? 0;
          avgAtt  = (att['average_attendance_rate']  as num?)?.toDouble() ?? 0;
        }
      }

      // Persist (TTL: 15 min)
      await CacheService.save(
        'coord_stats_${currentUser.userId}',
        {
          'total': total, 'completed': completed, 'active': active,
          'high_risk': 0, 'medium_risk': 0, 'low_risk': 0,
          'avg_completion': avgComp, 'avg_attendance': avgAtt,
        },
        ttl: const Duration(minutes: 15),
      );

      totalStudents      = total;
      completedOjt       = completed;
      activeOjt          = active;
      avgCompletionRatio = avgComp;
      avgAttendanceRate  = avgAtt;
      isFromCache        = false;
      errorMessage       = null;
    } catch (e) {
      debugPrint('[CoordinatorProvider] stats error: $e');
      final user   = await AuthService.getCurrentUser();
      final cached = user != null
          ? await CacheService.load('coord_stats_${user.userId}', ignoreTtl: true)
          : null;
      if (cached != null) {
        totalStudents      = (cached['total']          as int?)    ?? 0;
        completedOjt       = (cached['completed']       as int?)    ?? 0;
        activeOjt          = (cached['active']           as int?)    ?? 0;
        highRiskStudents   = (cached['high_risk']        as int?)    ?? 0;
        mediumRiskStudents = (cached['medium_risk']      as int?)    ?? 0;
        lowRiskStudents    = (cached['low_risk']         as int?)    ?? 0;
        avgCompletionRatio = (cached['avg_completion']   as num?)?.toDouble() ?? 0;
        avgAttendanceRate  = (cached['avg_attendance']   as num?)?.toDouble() ?? 0;
        isFromCache        = true;
        errorMessage       = null;
      } else {
        errorMessage = e.toString();
      }
    } finally {
      isLoadingStats = false;
      notifyListeners();
    }
  }
}

