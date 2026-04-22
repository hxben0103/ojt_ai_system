import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/ojt_service.dart';
import '../services/cache_service.dart';

/// Manages all data for the Student Dashboard.
/// Handles loading, caching, and error state so the UI widget only reads data.
class StudentProvider extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────────────
  bool isLoading = false;
  bool isFromCache = false;
  String? errorMessage;

  // Profile
  int? studentUserId;
  String? studentName;
  String? studentId;
  String? course;
  String? program;
  String? coordinator;
  String? supervisor;

  // Hours
  int completedHours = 0;
  int requiredHours = 300;

  // OJT status (full JSON map from API)
  Map<String, dynamic>? studentStatus;
  bool statusLoading = false;
  String? statusError;

  // ── Public API ─────────────────────────────────────────────────────────────

  Future<void> loadAll() async {
    isLoading = true;
    errorMessage = null;
    isFromCache = false;
    notifyListeners();

    try {
      await _loadProfile();
      if (studentUserId != null) {
        await _loadStudentStatus();
      }
      isFromCache = false;
      errorMessage = null;
    } catch (e) {
      debugPrint('[StudentProvider] Error: $e');
      final cached = studentUserId != null
          ? await CacheService.load('student_status_$studentUserId', ignoreTtl: true)
          : null;
      if (cached != null) {
        studentStatus = cached;
        isFromCache = true;
        errorMessage = null;
      } else {
        errorMessage = 'Failed to load data. Check your connection.';
      }
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => loadAll();

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<void> _loadProfile() async {
    final user = await AuthService.getCurrentUser();
    if (user != null) {
      studentUserId = user.userId;
      studentName   = user.fullName;
      studentId     = user.studentId ?? '${user.userId}';
      course        = user.course ?? 'N/A';
      program       = user.program ?? 'Not Specified';
      requiredHours = user.requiredHours ?? requiredHours;
    }
  }

  Future<void> _loadStudentStatus() async {
    statusLoading = true;
    statusError   = null;
    notifyListeners();

    try {
      final status = await OjtService.getStudentStatus(studentUserId!);

      // Persist to cache (TTL: 30 min)
      await CacheService.save(
        'student_status_$studentUserId',
        status,
        ttl: const Duration(minutes: 30),
      );

      studentStatus = status;
      if (status['hours'] != null) {
        final h = status['hours'] as Map<String, dynamic>;
        completedHours = _toInt(h['completed']) ?? completedHours;
        requiredHours  = _toInt(h['required'])  ?? requiredHours;
      }
      statusError = null;
    } catch (e) {
      debugPrint('[StudentProvider] status error: $e');
      final cached = await CacheService.load('student_status_$studentUserId', ignoreTtl: true);
      if (cached != null) {
        studentStatus = cached;
        isFromCache   = true;
        statusError   = null;
      } else {
        statusError = 'Unable to load status';
      }
    } finally {
      statusLoading = false;
      notifyListeners();
    }
  }

  int? _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }
}

