import 'package:flutter/material.dart';
import '../core/app_theme.dart';

/// A focused card for OJT hours and completion estimation.
/// Uses a slim progress bar and minimalistic typography.
class ProgressSummaryCard extends StatelessWidget {
  final int completedHours;
  final int requiredHours;
  final String? estimatedCompletion; // e.g., "~14 days"
  final Color accentColor;

  const ProgressSummaryCard({
    super.key,
    required this.completedHours,
    required this.requiredHours,
    this.estimatedCompletion,
    this.accentColor = AppTheme.studentPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = (requiredHours > 0) 
        ? (completedHours / requiredHours).clamp(0.0, 1.0) 
        : 0.0;
    
    final int percentage = (progress * 100).toInt();
    final int remaining = (requiredHours - completedHours).clamp(0, requiredHours);

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "OJT Hours",
                style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w700, color: Colors.grey[800]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "$percentage%",
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey[100],
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _statItem("Completed", "$completedHours hrs", Icons.check_circle_rounded),
              _verticalDivider(),
              _statItem("Remaining", "$remaining hrs", Icons.timer_rounded),
              if (estimatedCompletion != null) ...[
                _verticalDivider(),
                _statItem("Finish Date", estimatedCompletion!, Icons.event_available_rounded),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTheme.bodySmall.copyWith(color: Colors.grey[500], fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w700, color: Colors.grey[800]),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      height: 24,
      width: 1,
      color: Colors.grey[200],
    );
  }
}
