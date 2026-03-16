import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class ExplainableAiPanel extends StatelessWidget {
  final List<String> reasons;
  final String riskLevel;
  final double confidence;
  final String? summary;
  final List<String>? recommendations;
  final String? predictionStage;

  const ExplainableAiPanel({
    Key? key,
    required this.reasons,
    required this.riskLevel,
    this.confidence = 0.0,
    this.summary,
    this.recommendations,
    this.predictionStage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (reasons.isEmpty) {
      return const SizedBox.shrink();
    }

    // Determine color based on risk level
    Color headerColor;
    IconData headerIcon;
    switch (riskLevel.toUpperCase()) {
      case 'HIGH':
        headerColor = AppTheme.errorColor;
        headerIcon = Icons.warning_amber_rounded;
        break;
      case 'MEDIUM':
        headerColor = AppTheme.warningColor;
        headerIcon = Icons.info_outline_rounded;
        break;
      case 'LOW':
      default:
        headerColor = AppTheme.successColor;
        headerIcon = Icons.check_circle_outline_rounded;
        break;
    }

    return Container(
      width: double.infinity,
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
          // Header Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: headerColor.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(headerIcon, color: headerColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  "Why this score?",
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: headerColor.withOpacity(0.9),
                  ),
                ),
                if (predictionStage != null) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: predictionStage == 'early' ? AppTheme.warningColor : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      predictionStage == 'early' ? "Early Prediction" : "Mature Prediction",
                      style: AppTheme.bodySmall.copyWith(
                        color: predictionStage == 'early' ? Colors.white : Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
                if (confidence > 0) ...[
                  if (predictionStage == null) const Spacer(),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      "${(confidence * 100).toStringAsFixed(0)}% Confidence",
                      style: AppTheme.bodySmall.copyWith(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Body Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "AI Reasoning",
                  style: AppTheme.bodySmall.copyWith(
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                if (summary != null && summary!.isNotEmpty)
                  // True AI Explanation Text
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.1)),
                    ),
                    child: Text(
                      summary!,
                      style: AppTheme.bodyMedium.copyWith(
                        color: Colors.grey.shade800,
                        height: 1.5,
                      ),
                    ),
                  )
                else if (reasons.isEmpty)
                  Text(
                    "Your current score is based on the available attendance and progress records.",
                    style: AppTheme.bodyMedium.copyWith(color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                  )
                else
                  ...reasons.map((reason) => _buildReasonBullet(_normalizeReason(reason))).toList(),

                // LLM Recommendations
                if (recommendations != null && recommendations!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    "Actionable Recommendations",
                    style: AppTheme.bodySmall.copyWith(
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...recommendations!.map((rec) => _buildReasonBullet(rec)).toList(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReasonBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6.0, right: 10.0),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AppTheme.bodyMedium.copyWith(
                color: Colors.grey.shade800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Maps raw backend reasoning variables to student-friendly language
  String _normalizeReason(String rawReason) {
    final lower = rawReason.toLowerCase();
    
    if (lower.contains('hours_completed_ratio is below satisfactory') || 
        lower.contains('low completed hours') ||
        lower.contains('0/300 hours')) {
      return 'No required OJT hours have been completed yet.';
    }
    
    if (lower.contains('hours_completed_ratio')) {
      return 'Completed hours are below the expected progress based on the timeline.';
    }
    
    if (lower.contains('low attendance rate') || lower.contains('attendance rate')) {
      return 'Attendance rate is currently showing inconsistency.';
    }
    
    if (lower.contains('few tasks logged') || lower.contains('0.0 tasks')) {
      return 'No daily tasks have been logged yet.';
    }
    
    if (lower.contains('supervisor evaluation not yet available')) {
      return 'Supervisor evaluation is pending. The score temporarily relies on attendance and task data.';
    }

    if (lower.contains('evaluation')) {
      return 'Supervisor evaluation indicates areas for improvement.';
    }

    if (lower.contains('geofence') || lower.contains('anomaly')) {
      return 'Some recent check-ins were flagged outside the designated location.';
    }

    // Capitalize first letter cleanly for unmapped reasons
    return rawReason.isEmpty 
        ? rawReason 
        : rawReason[0].toUpperCase() + rawReason.substring(1).replaceAll('_', ' ');
  }
}
