import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_theme.dart';
import '../models/ojt_record.dart';
import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import '../services/ojt_service.dart';
import '../services/prediction_service.dart';
import '../widgets/integrity_badge.dart';
import '../widgets/explainable_ai_card.dart';
import 'student_analytics_screen.dart';

class CoordinatorStudentMonitor extends StatefulWidget {
  const CoordinatorStudentMonitor({super.key});

  @override
  State<CoordinatorStudentMonitor> createState() => _CoordinatorStudentMonitorState();
}

class StudentMonitorEntry {
  StudentMonitorEntry({
    required this.name,
    required this.studentId,
    required this.hostCompany,
    required this.completedHours,
    required this.requiredHours,
    required this.lastDutyDate,
    required this.onDutyToday,
    this.riskLevel,
    this.riskProbability,
    this.todayAttendanceStatus, // 'Approved', 'Pending', 'Rejected', or null
    this.aiScore,
    this.aiTrend,
    this.integrityScore,
    this.flagsCaught,
    this.finalGradeForecast,
    this.predictionData,
  });

  final String name;
  final int studentId;
  final String hostCompany;
  final int completedHours;
  final int requiredHours;
  final String lastDutyDate;
  final bool onDutyToday;
  final String? riskLevel;
  final double? riskProbability;
  final String? todayAttendanceStatus; // Status of today's attendance if exists
  final double? aiScore;
  final String? aiTrend;
  final double? integrityScore;
  final List<String>? flagsCaught;
  final double? finalGradeForecast;
  final Map<String, dynamic>? predictionData;

  int get remainingHours => max(requiredHours - completedHours, 0);
  double get completionPercent =>
      requiredHours <= 0 ? 0 : (completedHours / requiredHours).clamp(0.0, 1.0);
  
  // Helper to get status text for today's attendance
  String get todayStatusText {
    if (onDutyToday) {
      if (flagsCaught != null && flagsCaught!.isNotEmpty) {
        return 'Flagged Activity';
      }
      return 'On Duty';
    } else {
      return 'Not on Duty Today';
    }
  }
  
  // Helper to get status color
  Color get todayStatusColor {
    if (onDutyToday) {
      if (flagsCaught != null && flagsCaught!.isNotEmpty) {
        return Colors.red;
      }
      return Colors.green;
    } else {
      return Colors.redAccent;
    }
  }
}

class _CoordinatorStudentMonitorState extends State<CoordinatorStudentMonitor> {
  final DateFormat _dateFormatter = DateFormat('yyyy-MM-dd');

  List<StudentMonitorEntry> _students = [];
  List<StudentMonitorEntry> _filteredStudents = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'name'; // 'name', 'risk', 'progress', 'integrity'
  bool _sortAscending = true;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadStudents();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _applyFilterAndSort();
    });
  }

  void _applyFilterAndSort() {
    List<StudentMonitorEntry> filtered = _students.where((student) {
      final nameMatches = student.name.toLowerCase().contains(_searchQuery);
      final companyMatches = student.hostCompany.toLowerCase().contains(_searchQuery);
      return nameMatches || companyMatches;
    }).toList();

    filtered.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'name':
          comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case 'risk':
          int getRiskPriority(String? risk) {
            switch (risk?.toUpperCase()) {
              case 'HIGH': return 3;
              case 'MEDIUM': return 2;
              case 'LOW': return 1;
              default: return 0;
            }
          }
          comparison = getRiskPriority(a.riskLevel).compareTo(getRiskPriority(b.riskLevel));
          break;
        case 'progress':
          comparison = a.completionPercent.compareTo(b.completionPercent);
          break;
        case 'integrity':
          comparison = (a.integrityScore ?? 100).compareTo(b.integrityScore ?? 100);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    if (!mounted) return;
    setState(() {
      _filteredStudents = filtered;
    });
  }

  Future<void> _loadStudents() async {
    if (!_isRefreshing) {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final currentUser = await AuthService.getCurrentUser();
      if (!mounted) return;
      
      if (currentUser == null) {
        setState(() {
          _error = 'User not logged in';
          _isLoading = false;
        });
        return;
      }

      final ojtRecords = await OjtService.getOjtRecords(
        coordinatorId: currentUser.userId,
      );

      if (!mounted) return;
      if (ojtRecords.isEmpty) {
        setState(() {
          _students = [];
          _isLoading = false;
          _error = null; // Not an error, just no students assigned
        });
        return;
      }

      final entries = await Future.wait(
        ojtRecords.map((record) => _buildStudentEntry(record)),
      );

      if (!mounted) return;
      setState(() {
        _students = entries.whereType<StudentMonitorEntry>().toList();
        _applyFilterAndSort();
        _isLoading = false;
        _isRefreshing = false;
        _error = null;
      });
    } catch (e, stackTrace) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load students: ${e.toString()}';
        _isLoading = false;
        _isRefreshing = false;
        _students = [];
      });
      debugPrint('[CoordinatorStudentMonitor] Error: $e\n$stackTrace');
    }
  }

  Future<StudentMonitorEntry?> _buildStudentEntry(OjtRecord record) async {
    try {
      final summary =
          await AttendanceService.getAttendanceSummary(record.studentId);

      final completedHours = (summary['total_hours_completed'] ?? 0).toInt();
      String? lastDutyDate = summary['last_duty_date'] as String?;

      if (lastDutyDate != null && lastDutyDate != 'N/A') {
        try {
          final parsed = DateTime.parse(lastDutyDate);
          lastDutyDate = _dateFormatter.format(parsed);
        } catch (_) {
          // keep original format
        }
      }

      // Check if student has logged attendance for today (any status)
      // Student is "on duty" if they have logged attendance, regardless of approval status
      bool onDutyToday = false;
      String? todayAttendanceStatus;
      try {
        final todayAttendance = await AttendanceService.getTodayAttendance(record.studentId);
        debugPrint('[CoordinatorStudentMonitor] Student ${record.studentId} today attendance: ${todayAttendance?.status ?? "null"}');
        if (todayAttendance != null) {
          todayAttendanceStatus = todayAttendance.status;
          // Student is "on duty" if they have logged attendance today (Pending, Approved, or Rejected)
          // The status will be shown separately to indicate approval state
          onDutyToday = true;
          debugPrint('[CoordinatorStudentMonitor] Student ${record.studentId} is on duty today with status: $todayAttendanceStatus');
        } else {
          debugPrint('[CoordinatorStudentMonitor] Student ${record.studentId} has no attendance logged for today');
        }
      } catch (e) {
        debugPrint(
            '[CoordinatorStudentMonitor] Error checking today attendance for ${record.studentId}: $e');
        // If check fails, default to false (not on duty)
        onDutyToday = false;
        todayAttendanceStatus = null;
      }

      String? riskLevel;
      double? riskProbability;
      double? aiScore;
      String? aiTrend;
      double? integrityScore;
      List<String>? flagsCaught;
      double? finalGradeForecast;

      Map<String, dynamic>? prediction;
      try {
        final rawPrediction = await PredictionService.getDailyPrediction(record.studentId);
        prediction = Map<String, dynamic>.from(rawPrediction);
        
        if (prediction['ai_prediction'] != null) {
          final aiPred = Map<String, dynamic>.from(prediction['ai_prediction'] as Map);
          
          // Try to get risk level from ml_prediction object OR top-level risk_level key
          if (aiPred['ml_prediction'] != null) {
            final ml = Map<String, dynamic>.from(aiPred['ml_prediction'] as Map);
            riskLevel = (ml['risk_level'] as String? ?? aiPred['risk_level'] as String?)?.toUpperCase();
            riskProbability = (ml['probability'] as num? ?? ml['confidence'] as num? ?? aiPred['probability'] as num?)?.toDouble();
          } else if (aiPred['risk_level'] != null) {
            riskLevel = (aiPred['risk_level'] as String?)?.toUpperCase();
            riskProbability = (aiPred['probability'] as num? ?? aiPred['confidence'] as num?)?.toDouble();
          }
          
          if (aiPred['grading'] != null) {
            final grading = Map<String, dynamic>.from(aiPred['grading'] as Map);
            finalGradeForecast = (grading['forecasted_grade'] as num?)?.toDouble();
          }
          
          if (aiPred['trend'] != null) {
            final trend = Map<String, dynamic>.from(aiPred['trend'] as Map);
            aiTrend = trend['status'] as String?;
          }
          
          if (aiPred['integrity'] != null) {
            final integrity = Map<String, dynamic>.from(aiPred['integrity'] as Map);
            integrityScore = (integrity['integrity_score'] as num?)?.toDouble();
            flagsCaught = (integrity['flags_caught'] as List<dynamic>?)?.map((e) => e.toString()).toList();
          }
        }
      } catch (e) {
        debugPrint(
            '[CoordinatorStudentMonitor] Prediction error for ${record.studentId}: $e');
        riskLevel = 'UNAVAILABLE';
      }

      return StudentMonitorEntry(
        name: record.studentName ?? 'Unknown',
        studentId: record.studentId,
        hostCompany: record.companyName ?? 'N/A',
        completedHours: completedHours,
        requiredHours: record.requiredHours ?? 300,
        lastDutyDate: lastDutyDate ?? 'N/A',
        onDutyToday: onDutyToday, // Only true if approved attendance exists for today
        riskLevel: riskLevel,
        riskProbability: riskProbability,
        todayAttendanceStatus: todayAttendanceStatus, // Status of today's attendance
        aiScore: aiScore,
        aiTrend: aiTrend,
        integrityScore: integrityScore,
        flagsCaught: flagsCaught,
        finalGradeForecast: finalGradeForecast,
        predictionData: prediction,
      );
    } catch (e) {
      debugPrint(
          '[CoordinatorStudentMonitor] Failed to build entry for ${record.studentId}: $e');
      return StudentMonitorEntry(
        name: record.studentName ?? 'Unknown',
        studentId: record.studentId,
        hostCompany: record.companyName ?? 'N/A',
        completedHours: 0,
        requiredHours: record.requiredHours ?? 300,
        lastDutyDate: 'N/A',
        onDutyToday: false,
        riskLevel: null,
        riskProbability: null,
        todayAttendanceStatus: null,
        aiScore: null,
        aiTrend: null,
        integrityScore: null,
        flagsCaught: null,
        finalGradeForecast: null,
        predictionData: null,
      );
    }
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _isRefreshing = true;
    });
    await _loadStudents();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 72, color: Colors.grey[400]),
          const SizedBox(height: AppTheme.spacing16),
          const Text(
            'No students assigned to you yet.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppTheme.spacing8),
          const Text(
            'Students will appear here once OJT records are created.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spacing24),
          ElevatedButton.icon(
            onPressed: _loadStudents,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: AppTheme.primaryButtonStyle(AppTheme.coordinatorPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 72, color: Colors.red[400]),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing16),
            ElevatedButton(
              onPressed: _loadStudents,
              style: AppTheme.primaryButtonStyle(AppTheme.coordinatorPrimary),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(StudentMonitorEntry entry) {
    IconData icon;
    if (entry.onDutyToday) {
      if (entry.flagsCaught != null && entry.flagsCaught!.isNotEmpty) {
        icon = Icons.report_problem_rounded;
      } else {
        icon = Icons.check_circle_rounded;
      }
    } else {
      icon = Icons.event_busy_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: entry.todayStatusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: entry.todayStatusColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: entry.todayStatusColor,
          ),
          const SizedBox(width: 6),
          Text(
            entry.todayStatusText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: entry.todayStatusColor.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiDiagnostics(StudentMonitorEntry entry) {
    if (entry.riskLevel == null || entry.riskLevel == 'UNAVAILABLE') return const SizedBox.shrink();

    final isCritical = entry.riskLevel == 'HIGH' || entry.riskLevel == 'CRITICAL';
    final isWarning = entry.riskLevel == 'MEDIUM' || entry.riskLevel == 'NEEDS ATTENTION';
    
    Color riskColor = Colors.green.shade600;
    IconData riskIcon = Icons.check_circle_outline;
    if (isCritical) {
      riskColor = Colors.red.shade600;
      riskIcon = Icons.warning_amber_rounded;
    } else if (isWarning) {
      riskColor = Colors.orange.shade600;
      riskIcon = Icons.info_outline;
    }

    final double score = entry.aiScore ?? (100.0 - ((entry.riskProbability ?? 0) * 100));

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 18, color: AppTheme.coordinatorPrimary),
              const SizedBox(width: 8),
              Text('AI Insights', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
            ],
          ),
          const SizedBox(height: 16),
          // Row 1: Risk & Progress
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ML Risk Level', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(riskIcon, size: 16, color: riskColor),
                        const SizedBox(width: 4),
                        Text(
                          entry.riskLevel?.toUpperCase() ?? 'UNKNOWN',
                          style: TextStyle(fontWeight: FontWeight.w700, color: riskColor, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Progress Score', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 4),
                    Text(
                      '${score.toStringAsFixed(1)} / 100',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade800, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Row 2: Integrity & Forecast
          Row(
            children: [
              if (entry.integrityScore != null)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Integrity Score', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${entry.integrityScore?.toInt() ?? 100}',
                            style: TextStyle(
                              fontSize: 13, 
                              fontWeight: FontWeight.w600,
                              color: (entry.integrityScore ?? 100) < 70 ? Colors.red : Colors.green.shade700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          if (entry.flagsCaught != null && entry.flagsCaught!.isNotEmpty)
                            IntegrityBadge.trust(flaggedCount: entry.flagsCaught!.length, isCompact: true),
                        ],
                      ),
                    ],
                  ),
                ),
              if (entry.finalGradeForecast != null && entry.finalGradeForecast! > 0)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Forecasted Grade', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      const SizedBox(height: 4),
                      Text(
                        entry.finalGradeForecast!.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.coordinatorPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(StudentMonitorEntry entry) {
    final initials = entry.name.split(' ').where((p) => p.isNotEmpty).map((p) => p[0]).take(2).join();

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      color: Colors.white,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
          leading: CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey.shade100,
            child: Text(
              initials, 
              style: TextStyle(
                color: Colors.grey.shade700, 
                fontWeight: FontWeight.bold,
                fontSize: 14,
              )
            ),
          ),
          title: Text(
            entry.name,
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.grey.shade900),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                entry.hostCompany, 
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w500)
              ),
              const SizedBox(height: 8),
              _buildStatusChip(entry),
            ],
          ),
          children: [
            const SizedBox(height: 16),
            // Progress Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Completion Progress',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Colors.grey.shade700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${entry.completedHours} / ${entry.requiredHours} hrs',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade900),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: entry.completionPercent,
                minHeight: 6,
                backgroundColor: Colors.grey.shade100,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.coordinatorPrimary),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${(entry.completionPercent * 100).toStringAsFixed(1)}%', style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                Flexible(
                  child: Text(
                    '${entry.remainingHours} hrs remaining',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
              ExplainableAiCard(
                prediction: entry.predictionData!,
                isExpanded: true,
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StudentAnalyticsScreen(
                      studentName: entry.name,
                      studentId: entry.studentId.toString(),
                      course: entry.hostCompany,
                      userId: entry.studentId,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.insights_rounded),
              label: const Text("View Student Analytics Timeline"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.coordinatorPrimary.withOpacity(0.1),
                foregroundColor: AppTheme.coordinatorPrimary,
                elevation: 0,
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppTheme.coordinatorPrimary.withOpacity(0.2)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: _isSearching 
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search student, HTE, or company...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.white70),
              ),
              style: const TextStyle(color: Colors.white, fontSize: 16),
            )
          : const Text("Student Monitor"),
        backgroundColor: AppTheme.coordinatorPrimary,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchController.clear();
                  _isSearching = false;
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              setState(() {
                if (_sortBy == value) {
                  _sortAscending = !_sortAscending;
                } else {
                  _sortBy = value;
                  _sortAscending = true;
                }
                _applyFilterAndSort();
              });
            },
            itemBuilder: (context) => [
              _buildSortItem('name', 'Sort by Name', Icons.sort_by_alpha),
              _buildSortItem('risk', 'Sort by Risk', Icons.warning_amber_rounded),
              _buildSortItem('progress', 'Sort by Progress', Icons.trending_up),
              _buildSortItem('integrity', 'Sort by Integrity', Icons.verified_user_outlined),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStudents,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
                ? _buildErrorState()
                : _filteredStudents.isEmpty
                    ? (_searchQuery.isNotEmpty 
                        ? Center(child: Text('No students match "$_searchQuery"'))
                        : _buildEmptyState())
                    : RefreshIndicator(
                        onRefresh: _handleRefresh,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(AppTheme.spacing16),
                          itemCount: _filteredStudents.length,
                          itemBuilder: (context, index) =>
                              _buildStudentCard(_filteredStudents[index]),
                        ),
                      ),
    );
  }

  PopupMenuItem<String> _buildSortItem(String value, String label, IconData icon) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: _sortBy == value ? AppTheme.coordinatorPrimary : Colors.grey),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
          if (_sortBy == value)
            Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
              color: AppTheme.coordinatorPrimary,
            ),
        ],
      ),
    );
  }

  Color _getRiskColor(String? riskLevel) {
    switch (riskLevel?.toUpperCase()) {
      case 'HIGH':
        return Colors.red;
      case 'MEDIUM':
        return Colors.orange;
      case 'LOW':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getRiskIcon(String? riskLevel) {
    switch (riskLevel?.toUpperCase()) {
      case 'HIGH':
        return Icons.warning;
      case 'MEDIUM':
        return Icons.info;
      case 'LOW':
        return Icons.check_circle;
      default:
        return Icons.help_outline;
    }
  }
}
