import 'package:flutter/material.dart';
import '../core/app_theme.dart';

/// Compact horizontal stat card for 4-up stat rows in coordinator/admin/supervisor dashboards.
/// Much more space-efficient than the full StatCard.
class ModernStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const ModernStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Safety check for null properties that can crash JS runtime
    final displayValue = value.isEmpty ? '0' : value;
    final displayLabel = label.isEmpty ? 'Stat' : label;
    final displayColor = color;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppTheme.spacing16,
            horizontal: AppTheme.spacing12,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
            boxShadow: AppTheme.softShadow,
            border: Border.all(color: displayColor.withOpacity(0.05), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: displayColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: displayColor),
              ),
              const SizedBox(height: 12),
              Text(
                displayValue,
                style: AppTheme.heading2.copyWith(
                  color: displayColor,
                  fontSize: 22,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                displayLabel.toUpperCase(),
                textAlign: TextAlign.center,
                style: AppTheme.caption.copyWith(
                  fontSize: 10,
                  color: Colors.blueGrey.shade500,
                  letterSpacing: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

