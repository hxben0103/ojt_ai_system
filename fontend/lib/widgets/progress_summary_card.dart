import 'package:flutter/material.dart';
import '../core/app_theme.dart';

/// A focused card for OJT hours and completion estimation.
/// Uses a slim progress bar and minimalistic typography.
class ProgressSummaryCard extends StatelessWidget {
  final int completedHours;
  final int requiredHours;
  final String? estimatedCompletion; // e.g., "~14 days"
  final Color accentColor;
  final VoidCallback? onTap;

  const ProgressSummaryCard({
    super.key,
    required this.completedHours,
    required this.requiredHours,
    this.estimatedCompletion,
    this.accentColor = AppTheme.studentPrimary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = (requiredHours > 0) 
        ? (completedHours / requiredHours).clamp(0.0, 1.0) 
        : 0.0;
    
    final int percentage = (progress * 100).toInt();
    final int remaining = (requiredHours - completedHours).clamp(0, requiredHours);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16, vertical: AppTheme.spacing8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.softShadow,
        border: Border.all(color: Colors.blueGrey.shade50, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "OJT Progress",
                style: AppTheme.heading3.copyWith(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.blueGrey.shade900),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  "$percentage%",
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.blueGrey.shade50,
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _statItem("Completed", "$completedHours HRS", Icons.check_circle_rounded, accentColor),
              _statItem("Remaining", "$remaining HRS", Icons.timer_rounded, Colors.blueGrey.shade400),
              if (estimatedCompletion != null)
                _statItem("Finishing In", estimatedCompletion!, Icons.auto_awesome_rounded, Colors.indigo.shade400),
            ],
          ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 10, color: color.withOpacity(0.5)),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: AppTheme.caption.copyWith(color: Colors.blueGrey.shade400, fontSize: 8, letterSpacing: 0.8),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w800, color: Colors.blueGrey.shade800, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

