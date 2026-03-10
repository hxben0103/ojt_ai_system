import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import 'loading_skeleton.dart';

/// A primary card for AI Performance Prediction and Explainable AI insights.
/// Focuses on visual hierarchy and clear status indication.
class InsightCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final String statusLabel; // e.g., "On Track", "High Risk", "Needs Review"
  final Color statusColor;
  final double? progressValue; // 0.0 to 1.0
  final List<String> insights; // Bullet points
  final String? recommendation;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final Widget? trailing;

  const InsightCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.statusLabel,
    required this.statusColor,
    this.progressValue,
    this.insights = const [],
    this.recommendation,
    this.isLoading = false,
    this.errorMessage,
    this.onRetry,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
        child: LoadingSkeleton(height: 200),
      );
    }

    if (errorMessage != null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
        padding: const EdgeInsets.all(AppTheme.spacing16),
        decoration: BoxDecoration(
          color: AppTheme.errorColor.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.errorColor.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(Icons.error_outline_rounded, color: AppTheme.errorColor, size: 32),
            const SizedBox(height: 12),
            Text(
              "Intelligence Data Offline",
              style: AppTheme.heading3.copyWith(color: AppTheme.errorColor),
            ),
            const SizedBox(height: 4),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: AppTheme.bodySmall,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text("Retry Analytics"),
                style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      padding: const EdgeInsets.all(AppTheme.spacing20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [AppTheme.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: statusColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTheme.heading3),
                    if (subtitle != null)
                      Text(subtitle!, style: AppTheme.bodySmall.copyWith(color: Colors.grey[600])),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (progressValue != null) ...[
                SizedBox(
                  width: 60,
                  height: 60,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: progressValue,
                        strokeWidth: 6,
                        backgroundColor: statusColor.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        strokeCap: StrokeCap.round,
                      ),
                      Center(
                        child: Text(
                          "${(progressValue! * 100).toInt()}%",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusLabel.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: statusColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (recommendation != null)
                      Text(
                        recommendation!,
                        style: AppTheme.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (insights.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),
            ...insights.map((insight) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 14, color: statusColor.withOpacity(0.5)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          insight,
                          style: AppTheme.bodySmall.copyWith(height: 1.4),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
