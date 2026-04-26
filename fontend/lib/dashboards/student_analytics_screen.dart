import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/attendance.dart';
import '../services/prediction_service.dart';
import '../services/attendance_service.dart';
import '../services/ojt_service.dart';
import '../widgets/daily_rhythm_chart.dart';
import '../widgets/explainable_ai_panel.dart';
import '../core/app_theme.dart';
import 'student_dtr_view_screen.dart';

class StudentAnalyticsScreen extends StatefulWidget {
  final String studentName;
  final String studentId;
  final String course;
  final int userId;
  final String? supervisorName; // Added supervisor name

  const StudentAnalyticsScreen({
    super.key,
    required this.studentName,
    required this.studentId,
    required this.course,
    required this.userId,
    this.supervisorName,
  });

  @override
  State<StudentAnalyticsScreen> createState() => _StudentAnalyticsScreenState();
}

class _StudentAnalyticsScreenState extends State<StudentAnalyticsScreen> {
  bool _isLoading = true;
  List<Attendance> _attendanceRecords = [];
  Map<String, dynamic>? _integrityData;
  Map<String, dynamic>? _aiPrediction;
  double _totalHours = 0;
  String? _supervisorName; // Local supervisor name state

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      _supervisorName = widget.supervisorName;
      
      final records = await AttendanceService.getAttendance(studentId: widget.userId);
      
      // If supervisor name is missing (e.g., student viewing their own analytics), fetch OJT record
      if (_supervisorName == null) {
        try {
          final ojtRecords = await OjtService.getOjtRecords(studentId: widget.userId);
          if (ojtRecords.isNotEmpty) {
            _supervisorName = ojtRecords.first.supervisorName;
          }
        } catch (e) {
          debugPrint("Note: Could not fetch OJT record for supervisor name: $e");
        }
      }
      Map<String, dynamic>? prediction;
      try {
        prediction = await PredictionService.getDailyPrediction(widget.userId, cacheOnly: false);
      } catch (e) {
        debugPrint("Note: AI integrity data not available: $e");
      }
      
      double total = 0;
      for (var r in records) {
        if (r.status == 'Approved') {
          total += r.totalHours ?? 0;
        }
      }

      if (mounted) {
        setState(() {
          _attendanceRecords = records;
          if (prediction != null) {
            _integrityData = prediction['payload']?['integrity_analysis'] ?? prediction['integrity_analysis'];
            _aiPrediction = prediction['ai_prediction'] ?? prediction['ml_prediction'];
          }
          _totalHours = total;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading analytics data: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: Text(
          "Student Analytics",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.coordinatorPrimary))
        : _buildMainContent(),
    );
  }

  Widget _buildMainContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                _buildHeaderInfo(),
                const SizedBox(height: 25),
                _buildSummaryGrid(),
                const SizedBox(height: 30),
                _buildSectionLabel("Daily activity", "Detailed rhythm tracker"),
                const SizedBox(height: 15),
                _buildCard(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  child: DailyRhythmChart(records: _attendanceRecords),
                ),
                const SizedBox(height: 30),
                if (_aiPrediction != null) ...[
                  _buildSectionLabel("Performance Insight", "AI-driven success forecast"),
                  const SizedBox(height: 15),
                  ExplainableAiPanel(
                    reasons: List<String>.from(_aiPrediction!['top_reasons'] ?? []),
                    riskLevel: _aiPrediction!['risk_level'] ?? 'LOW',
                    confidence: (_aiPrediction!['confidence'] ?? 0.0).toDouble(),
                    summary: _aiPrediction!['summary'] ?? _aiPrediction!['recommendation'],
                  ),
                  const SizedBox(height: 30),
                ],
                if (_integrityData != null) ...[
                  _buildSectionLabel("Integrity Insight", "Anti-fraud analysis"),
                  const SizedBox(height: 15),
                  _buildIntegrityCard(),
                  const SizedBox(height: 30),
                ],
                _buildExportButton(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.coordinatorPrimary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.coordinatorPrimary.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppTheme.coordinatorPrimary.withOpacity(0.1),
            child: Text(
              widget.studentName.substring(0, 1).toUpperCase(),
              style: GoogleFonts.outfit(
                color: AppTheme.coordinatorPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.studentName,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  widget.course,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            "Hours Logged",
            _totalHours.toStringAsFixed(1),
            Icons.access_time_filled,
            AppTheme.coordinatorPrimary,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _buildStatCard(
            "Attendance",
            _attendanceRecords.length.toString(),
            Icons.calendar_month,
            AppTheme.successColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return _buildCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 15),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntegrityCard() {
    final score = _integrityData?['score'] ?? 100;
    final status = _integrityData?['status'] ?? 'GOOD';
    final flags = List<String>.from(_integrityData?['flags'] ?? []);

    Color scoreColor = AppTheme.successColor;
    if (status == 'CRITICAL') scoreColor = AppTheme.errorColor;
    else if (status == 'SUSPICIOUS') scoreColor = AppTheme.warningColor;

    return _buildCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Timing Veracity",
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scoreColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: GoogleFonts.outfit(
                    color: scoreColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: score / 100.0,
              backgroundColor: Colors.black.withOpacity(0.05),
              color: scoreColor,
              minHeight: 12,
            ),
          ),
          const SizedBox(height: 15),
          if (flags.isNotEmpty)
            ...flags.map((f) => Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.report_problem_rounded, color: scoreColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f,
                      style: GoogleFonts.outfit(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            )).toList()
          else
            Text(
              "No irregularities detected",
              style: GoogleFonts.outfit(fontSize: 13, color: Colors.black38, fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }

  Widget _buildExportButton() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.coordinatorPrimary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      onPressed: () {
        final formattedRecords = _attendanceRecords.map((a) {
          return {
            'date': DateFormat('yyyy-MM-dd').format(a.date),
            'amIn': a.morningIn != null ? _formatTime(a.morningIn!) : "-",
            'amOut': a.morningOut != null ? _formatTime(a.morningOut!) : "-",
            'pmIn': a.afternoonIn != null ? _formatTime(a.afternoonIn!) : "-",
            'pmOut': a.afternoonOut != null ? _formatTime(a.afternoonOut!) : "-",
            'otIn': a.overtimeIn != null ? _formatTime(a.overtimeIn!) : "-",
            'otOut': a.overtimeOut != null ? _formatTime(a.overtimeOut!) : "-",
            'status': a.status,
            'deductionMinutes': a.deductionMinutes ?? 0,
            'totalHours': a.totalHours?.toStringAsFixed(1) ?? "0.0",
          };
        }).toList();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StudentDTRViewScreen(
               studentName: widget.studentName,
               studentId: widget.studentId,
               course: widget.course,
               supervisorName: _supervisorName,
               dtrRecords: formattedRecords,
            ),
          ),
        );
      },
      icon: const Icon(Icons.picture_as_pdf),
      label: Text(
        "Print Official DTR",
        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSectionLabel(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        Text(
          subtitle,
          style: GoogleFonts.outfit(fontSize: 12, color: Colors.black45),
        ),
      ],
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
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  String _formatTime(String time) {
    try {
      if (time == "-" || time.isEmpty) return "-";
      final parts = time.split(':');
      if (parts.length < 2) return time;
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);
      final period = hour >= 12 ? "PM" : "AM";
      hour = hour % 12;
      if (hour == 0) hour = 12;
      return "$hour:${minute.toString().padLeft(2, '0')} $period";
    } catch (e) {
      return time;
    }
  }
}

