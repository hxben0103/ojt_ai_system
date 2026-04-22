import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class PerformanceTrendIndicator extends StatelessWidget {
  final int progressScore;
  final String trendDirection; // "Improving", "Stable", "Declining"
  final String trendReason;

  const PerformanceTrendIndicator({
    Key? key,
    required this.progressScore,
    required this.trendDirection,
    required this.trendReason,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    IconData trendIcon;
    Color trendColor;
    String trendText;

    switch (trendDirection.toLowerCase()) {
      case 'improving':
        trendIcon = Icons.arrow_upward;
        trendColor = AppTheme.successColor;
        trendText = '▲ Improving';
        break;
      case 'declining':
        trendIcon = Icons.arrow_downward;
        trendColor = AppTheme.errorColor;
        trendText = '▼ Declining';
        break;
      case 'stable':
      default:
        trendIcon = Icons.remove;
        trendColor = Colors.blue.shade600;
        trendText = '▬ Stable';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress Score: $progressScore%',
                style: AppTheme.heading3,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: trendColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
                ),
                child: Text(
                  trendText,
                  style: AppTheme.bodySmall.copyWith(
                    color: trendColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
          Text(
            'Reason:',
            style: AppTheme.bodySmall.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            trendReason,
            style: AppTheme.bodySmall.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

