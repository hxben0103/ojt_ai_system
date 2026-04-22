import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/attendance.dart';
import '../../models/daily_task.dart';
import '../../models/ojt_record.dart';
import '../../services/attendance_service.dart';
import '../../services/daily_task_service.dart';
import '../../services/prediction_service.dart';
import '../../core/app_theme.dart';
import '../../widgets/daily_rhythm_chart.dart';
import '../../widgets/modern_stat_card.dart';
import '../../widgets/integrity_badge.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/section_header.dart';
import '../../widgets/insight_card.dart';
import 'supervisor_evaluation_form_screen.dart';

class StudentDetailScreen extends StatefulWidget {
  final OjtRecord record;

  const StudentDetailScreen({
    super.key,
    required this.record,
  });

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  bool _isLoading = true;
  List<Attendance> _attendanceRecords = [];
  List<DailyTask> _recentTasks = [];
  Map<String, dynamic>? _aiPrediction;
  double _totalHours = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        AttendanceService.getAttendance(studentId: widget.record.studentId),
        DailyTaskService.getDailyTasksForStudent(widget.record.studentId),
        PredictionService.getDailyPrediction(widget.record.studentId, cacheOnly: true),
      ]);

      final records = results[0] as List<Attendance>;
      final tasks = results[1] as List<DailyTask>;
      final prediction = results[2] as Map<String, dynamic>;

      double total = 0;
      for (var r in records) {
        if (r.status == 'Approved') {
          total += r.totalHours ?? 0;
        }
      }

      if (mounted) {
        setState(() {
          _attendanceRecords = records;
          _recentTasks = tasks;
          _aiPrediction = prediction;
          _totalHours = total;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading student details: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: Text(
          widget.record.studentName ?? "Student Detail",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
           IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.supervisorPrimary))
        : _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileCard(),
          const SizedBox(height: 24),
          
          _buildSectionHeader("Performance Overview", Icons.analytics_rounded),
          const SizedBox(height: 16),
          _buildStatsRow(),
          const SizedBox(height: 24),

          _buildSectionHeader("Daily Rhythm", Icons.av_timer_rounded),
          const SizedBox(height: 12),
          _buildCard(
            padding: const EdgeInsets.all(20),
            child: DailyRhythmChart(records: _attendanceRecords),
          ),
          const SizedBox(height: 24),

          if (_aiPrediction != null) ...[
            _buildSectionHeader("AI Risk Analysis", Icons.psychology_rounded),
            const SizedBox(height: 12),
            _buildAiInsightCard(),
            const SizedBox(height: 24),
          ],

          _buildSectionHeader("Recent Tasks", Icons.assignment_turned_in_rounded),
          const SizedBox(height: 12),
          _buildTasksList(),
          
          const SizedBox(height: 32),
          _buildEvaluationAction(),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.supervisorPrimary),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.supervisorPrimary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.supervisorPrimary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 35,
            backgroundColor: AppTheme.supervisorPrimary.withOpacity(0.1),
            child: Text(
              (widget.record.studentName ?? "S")[0].toUpperCase(),
              style: GoogleFonts.outfit(
                color: AppTheme.supervisorPrimary,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.record.studentName ?? "Unknown",
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  "ID: ${widget.record.schoolId ?? 'N/A'}",
                  style: GoogleFonts.outfit(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStatusColor(widget.record.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    widget.record.status,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(widget.record.status),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: ModernStatCard(
            label: "Hours Rendered",
            value: _totalHours.toStringAsFixed(1),
            icon: Icons.timer_rounded,
            color: AppTheme.supervisorPrimary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ModernStatCard(
            label: "Tasks Logged",
            value: _recentTasks.length.toString(),
            icon: Icons.task_alt_rounded,
            color: Colors.teal,
          ),
        ),
      ],
    );
  }

  Widget _buildAiInsightCard() {
    final ai = _aiPrediction!['ai_prediction'] ?? {};
    final riskLevel = (ai['risk_level'] ?? 'LOW').toString().toUpperCase();
    final summary = ai['summary'] ?? "Overall performance is stable.";
    
    Color riskColor = AppTheme.successColor;
    if (riskLevel == 'HIGH') riskColor = AppTheme.errorColor;
    else if (riskLevel == 'MEDIUM') riskColor = AppTheme.warningColor;

    return InsightCard(
      title: "AI Risk Snapshot",
      subtitle: "Daily risk prediction of OJT failure/delays",
      icon: Icons.auto_awesome_rounded,
      statusLabel: riskLevel,
      statusColor: riskColor,
      progressValue: 1.0 - (ai['score'] ?? 0.0) / 100.0,
      insights: [summary],
      recommendation: ai['recommendation'] ?? "Continue routine supervision.",
    );
  }

  Widget _buildTasksList() {
    if (_recentTasks.isEmpty) {
      return _buildCard(
        padding: const EdgeInsets.all(24),
        child: const Center(child: Text("No tasks logged yet.")),
      );
    }

    final tasks = _recentTasks.take(5).toList();
    return Column(
      children: tasks.map((task) => _buildTaskTile(task)).toList(),
    );
  }

  Widget _buildTaskTile(DailyTask task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.supervisorPrimary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.assignment_outlined, size: 20, color: AppTheme.supervisorPrimary),
        ),
        title: Text(
          task.taskDescription,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          "${DateFormat('MMM dd').format(task.date)} • ${task.hoursWorked} hrs",
          style: GoogleFonts.outfit(fontSize: 12),
        ),
        trailing: Icon(
          task.status == 'Approved' ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
          color: task.status == 'Approved' ? AppTheme.successColor : AppTheme.warningColor,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildEvaluationAction() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.supervisorPrimary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        shadowColor: AppTheme.supervisorPrimary.withOpacity(0.4),
      ),
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupervisorEvaluationFormScreen())),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.rate_review_rounded),
          const SizedBox(width: 12),
          Text(
            "Perform Evaluation",
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'Evaluation Pending') return AppTheme.warningColor;
    if (status == 'Active' || status == 'Ongoing') return AppTheme.successColor;
    return Colors.grey;
  }
}

