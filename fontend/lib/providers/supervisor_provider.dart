import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/ojt_service.dart';
import '../services/evaluation_service.dart';
import '../services/cache_service.dart';
import '../models/ojt_record.dart';

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

  // Students
  List<OjtRecord> assignedStudents = [];
  int totalAssigned        = 0;
  int pendingEvaluations   = 0;

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

  Future<void> _loadProfile() async {
    try {
      final user = await AuthService.getCurrentUser();
      if (user != null) {
        fullName = user.fullName;
        idNumber = user.userId?.toString() ?? user.email;
        office   = user.course ?? 'N/A';
        position = user.role;
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
      final records = await OjtService.getOjtRecords(supervisorId: supervisorId);

      int pendingCount = 0;
      for (final record in records) {
        try {
          final evals = await EvaluationService.getEvaluations(
            studentId: record.studentId,
            supervisorId: supervisorId,
          );
          if (!evals.any((e) => (e.status ?? '').toLowerCase() == 'completed')) {
            pendingCount++;
          }
        } catch (_) {
          pendingCount++;
        }
      }

      // Persist (TTL: 20 min)
      await CacheService.save(
        'supervisor_students_$supervisorId',
        {'total': records.length, 'pending_evaluations': pendingCount},
        ttl: const Duration(minutes: 20),
      );

      assignedStudents   = records;
      totalAssigned      = records.length;
      pendingEvaluations = pendingCount;
      isFromCache        = false;
      errorMessage       = null;
    } catch (e) {
      debugPrint('[SupervisorProvider] error: $e');
      final user = await AuthService.getCurrentUser();
      final cached = user?.userId != null
          ? await CacheService.load('supervisor_students_${user!.userId}', ignoreTtl: true)
          : null;

      if (cached != null) {
        totalAssigned      = (cached['total']               as int?) ?? 0;
        pendingEvaluations = (cached['pending_evaluations'] as int?) ?? 0;
        isFromCache        = true;
        errorMessage       = null;
      } else {
        assignedStudents   = [];
        totalAssigned      = 0;
        pendingEvaluations = 0;
        errorMessage = 'Failed to load student data. Check your connection.';
      }
    } finally {
      isLoadingStudents = false;
      notifyListeners();
    }
  }
}
