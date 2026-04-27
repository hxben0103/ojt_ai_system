import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class WeeklyAiSummaryCard extends StatelessWidget {
  final Map<String, dynamic>? studentStatus;
  final String recommendation;

  const WeeklyAiSummaryCard({
    super.key,
    required this.studentStatus,
    required this.recommendation,
  });

  @override
  Widget build(BuildContext context) {
    if (studentStatus == null) return const SizedBox.shrink();

    // Derive UI values from backend status defensively
    final hours = studentStatus!['hours'] != null 
        ? Map<String, dynamic>.from(studentStatus!['hours'] as Map)
        : null;
    final int completed = _parseInt(hours?['completed']) ?? 0;
    final int required = _parseInt(hours?['required']) ?? 300;
    final double completionRatio = required > 0 ? (completed / required) : 0.0;

    final attendance = studentStatus!['attendance'] != null 
        ? Map<String, dynamic>.from(studentStatus!['attendance'] as Map)
        : null;
    final int daysPresent = _parseInt(attendance?['days_present']) ?? 0;
    final double targetDays = required > 0 ? (required / 8) : 25; // Estimate 8 hours a day
    final double attendanceRate = targetDays > 0 ? (daysPresent / targetDays) * 100 : 0.0;
    
    // Evaluate performance intuitively
    String performanceStatus = "Stable";
    Color performanceColor = Colors.blue.shade600;
    if (completionRatio > 0.5 && daysPresent > 15) {
      performanceStatus = "Improving";
      performanceColor = AppTheme.successColor;
    } else if (completionRatio < 0.2 && daysPresent < 5) {
      performanceStatus = "Needs Attention";
      performanceColor = AppTheme.errorColor;
    }

    // Evaluate attendance intuitively
    String attendanceStatus = "Stable";
    Color attendanceColor = Colors.blue.shade600;
    if (attendanceRate >= 90) {
      attendanceStatus = "Excellent";
      attendanceColor = AppTheme.successColor;
    } else if (attendanceRate < 70 && daysPresent > 0) {
      attendanceStatus = "Declining";
      attendanceColor = AppTheme.warningColor;
    }

    // Evaluate integrity intuitively (Assuming mostly Verified if using app properly)
    final aiInsight = studentStatus!['ai_insight'] != null 
        ? Map<String, dynamic>.from(studentStatus!['ai_insight'] as Map)
        : null;
    final riskLevel = (aiInsight?['risk_level'] as String? ?? 'LOW').toUpperCase();
    String integrityStatus = riskLevel != 'HIGH' ? "Verified" : "Pending Verification";
    Color integrityColor = riskLevel != 'HIGH' ? AppTheme.successColor : AppTheme.warningColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppTheme.studentPrimary, size: 20),
              const SizedBox(width: 8),
              Text(
                "Weekly AI Summary",
                style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          LayoutBuilder(builder: (context, constraints) {
            return Row(
              children: [
                Expanded(
                  child: _buildStatusRow(
                    "Attendance", 
                    attendanceStatus, 
                    attendanceColor
                  ),
                ),
                Expanded(
                  child: _buildStatusRow(
                    "Performance", 
                    performanceStatus, 
                    performanceColor
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 12),
          _buildStatusRow(
            "Integrity", 
            integrityStatus, 
            integrityColor
          ),
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(height: 1),
          ),
          
          if (aiInsight?['gemma_explanation'] != null) ...[
            Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.purple.shade400, size: 16),
                const SizedBox(width: 8),
                Text(
                  "AI Narrative",
                  style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold, color: Colors.purple.shade700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.shade50.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purple.shade100.withOpacity(0.5)),
              ),
              child: Text(
                aiInsight!['gemma_explanation'] as String,
                style: AppTheme.bodySmall.copyWith(
                  color: Colors.purple.shade900,
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Recommendation: ",
                style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: Text(
                  _cleanRecommendation(recommendation),
                  style: AppTheme.bodySmall.copyWith(color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color statusColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Padding(
            padding: const EdgeInsets.only(right: 4.0),
            child: Text(
              "$label:",
              style: AppTheme.bodySmall.copyWith(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value,
            style: AppTheme.bodySmall.copyWith(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }

  String _cleanRecommendation(String text) {
    if (text.isEmpty) return "Continue logging your tasks and attendance.";
    
    // Soften harsh backend verbiage for the student view
    String cleanText = text;
    if (cleanText.toLowerCase().contains("immediate action required")) {
      cleanText = "Focus on improving attendance consistency and completing daily tasks this week.";
    } else {
       final sentences = cleanText.split('.');
       cleanText = "${sentences.first.trim()}.";
    }

    return cleanText;
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
}

