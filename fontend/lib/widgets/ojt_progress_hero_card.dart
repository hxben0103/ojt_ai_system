import 'package:flutter/material.dart';
import '../core/app_theme.dart';

/// Hero card for the student dashboard showing a large circular progress
/// indicator with a supportive status message and AI insight bullets.
/// Never shows "HIGH RISK" — uses student-facing progress language.
class OjtProgressHeroCard extends StatelessWidget {
  /// 0–100 representing percent
  final int progressPercent;

  /// "On Track" | "Needs Attention" | "Keep Going"
  final String statusLabel;

  /// Color derived from progressPercent
  final Color statusColor;

  /// AI insight bullet points (max 2 shown)
  final List<String> insights;

  /// Whether AI data is still loading
  final bool isLoading;

  const OjtProgressHeroCard({
    super.key,
    required this.progressPercent,
    required this.statusLabel,
    required this.statusColor,
    this.insights = const [],
    this.isLoading = false,
  });

  static OjtProgressHeroCard fromAiInsight({
    Key? key,
    required Map<String, dynamic>? aiInsight,
    bool isLoading = false,
  }) {
    final riskLevel =
        (aiInsight?['risk_level'] as String? ?? 'LOW').toUpperCase();
        
    // Prefer unified schema fields, fallback to legacy fields
    final reasonsList = (aiInsight?['key_factors'] as List?) ?? 
                        (aiInsight?['top_reasons'] as List?) ?? [];
    final topReasons = reasonsList.cast<String>();

    // Convert risk level to student-friendly progress percentage
    int pct = 0;
    
    if (aiInsight != null && aiInsight.containsKey('score') && aiInsight['score'] != null) {
      // Use ML Progress Score if available
      pct = (aiInsight['score'] as num).toInt();
    } else {
      // Fallback inference - if no score API param exists, default to 0 and let caller calculate
      // However, we want the default OjtProgressHeroCard to still visualize something.
      // So if 'score' isn't explicitly passed, we pass it down computed from studentStatus.
      if (aiInsight != null && aiInsight.containsKey('computed_pct')) {
         pct = (aiInsight['computed_pct'] as num).toInt();
      } else {
        switch (riskLevel) {
          case 'LOW':
            pct = 82;
            break;
          case 'MEDIUM':
            pct = 65;
            break;
          default: // HIGH or no data
            pct = 48;
        }
      }
    }

    final String label;
    final Color color;
    
    if (pct >= 80) {
      label = 'On Track';
      color = AppTheme.successColor;
    } else if (pct >= 50) {
      label = 'Needs Attention';
      color = AppTheme.warningColor;
    } else {
      label = 'Critical Attention';
      color = AppTheme.errorColor;
    }
    
    // Check if gemma recommendation summary exists
    final List<String> insightsToDisplay = [];
    if (aiInsight?['summary'] != null && aiInsight?['summary'].toString().isNotEmpty == true) {
      insightsToDisplay.add(aiInsight!['summary'].toString());
    } else {
      insightsToDisplay.addAll(topReasons.take(2));
    }

    return OjtProgressHeroCard(
      key: key,
      progressPercent: pct,
      statusLabel: label,
      statusColor: color,
      insights: insightsToDisplay,
      isLoading: isLoading,
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = (progressPercent / 100).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      padding: const EdgeInsets.all(AppTheme.spacing24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: const [AppTheme.cardShadow],
      ),
      child: isLoading
          ? const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              children: [
                // Circular progress indicator
                SizedBox(
                  width: 130,
                  height: 130,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 10,
                        backgroundColor: statusColor.withOpacity(0.12),
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        strokeCap: StrokeCap.round,
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$progressPercent%',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: statusColor,
                                height: 1.1,
                              ),
                            ),
                            Text(
                              statusLabel,
                              style: AppTheme.bodySmall.copyWith(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // AI insight bullets
                if (insights.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spacing16),
                  const Divider(height: 1),
                  const SizedBox(height: AppTheme.spacing12),
                  ...insights.take(2).map(
                        (insight) => Padding(
                          padding: const EdgeInsets.only(
                              bottom: AppTheme.spacing8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.circle,
                                size: 6,
                                color: statusColor,
                              ),
                              const SizedBox(width: AppTheme.spacing8),
                              Expanded(
                                child: Text(
                                  insight,
                                  style: AppTheme.bodySmall.copyWith(
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                ],

                // Empty state: no data yet
                if (insights.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppTheme.spacing12),
                    child: Text(
                      'AI insights will appear after your first evaluation.',
                      textAlign: TextAlign.center,
                      style: AppTheme.bodySmall.copyWith(
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

