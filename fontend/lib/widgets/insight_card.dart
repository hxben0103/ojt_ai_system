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
            const Icon(Icons.error_outline_rounded, color: AppTheme.errorColor, size: 32),
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
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16, vertical: AppTheme.spacing8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: Colors.blueGrey.shade50, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title, 
                      style: AppTheme.heading3.copyWith(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.blueGrey.shade900)
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!, 
                        style: AppTheme.caption.copyWith(color: Colors.blueGrey.shade400, fontSize: 11)
                      ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (progressValue != null) ...[
                SizedBox(
                  width: 64,
                  height: 64,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: progressValue,
                        strokeWidth: 5,
                        backgroundColor: statusColor.withOpacity(0.05),
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                        strokeCap: StrokeCap.round,
                      ),
                      Center(
                        child: Text(
                          "${(progressValue! * 100).toInt()}%",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: statusColor,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        statusLabel.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                          letterSpacing: 1.1,
                          fontFamily: 'Plus Jakarta Sans',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (recommendation != null)
                      Text(
                        recommendation!,
                        style: AppTheme.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.blueGrey.shade700,
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (insights.isNotEmpty) ...[
            const SizedBox(height: 24),
            Divider(height: 1, color: Colors.blueGrey.shade50),
            const SizedBox(height: 16),
            ...insights.map((insight) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.auto_awesome_rounded, size: 10, color: statusColor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          insight,
                          style: AppTheme.bodySmall.copyWith(height: 1.5, color: Colors.blueGrey.shade600, fontWeight: FontWeight.w500),
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

