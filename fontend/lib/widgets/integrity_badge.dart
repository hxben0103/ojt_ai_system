import 'package:flutter/material.dart';
import '../core/app_theme.dart';

/// A standardized status badge for Geofencing, Photo Verification, and Trust Scoring.
/// Used inside rows or table cells across all dashboards.
class IntegrityBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isCompact;

  const IntegrityBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.isCompact = false,
  });

  factory IntegrityBadge.geofence({required bool inside, bool isCompact = false}) {
    return IntegrityBadge(
      icon: inside ? Icons.location_on_rounded : Icons.location_off_rounded,
      label: inside ? 'Inside Geofence' : 'Outside Geofence',
      color: inside ? AppTheme.successColor : AppTheme.warningColor,
      isCompact: isCompact,
    );
  }

  factory IntegrityBadge.photo({required bool verified, bool isCompact = false}) {
    return IntegrityBadge(
      icon: verified ? Icons.photo_camera_rounded : Icons.no_photography_rounded,
      label: verified ? 'Photo Verified' : 'Photo Pending',
      color: verified ? AppTheme.successColor : AppTheme.warningColor,
      isCompact: isCompact,
    );
  }

  factory IntegrityBadge.trust({required int flaggedCount, bool isCompact = false}) {
    final bool hasFlags = flaggedCount > 0;
    return IntegrityBadge(
      icon: hasFlags ? Icons.flag_rounded : Icons.verified_user_rounded,
      label: hasFlags ? '$flaggedCount Flagged' : 'High Trust',
      color: hasFlags ? AppTheme.errorColor : AppTheme.successColor,
      isCompact: isCompact,
    );
  }

  factory IntegrityBadge.flagged({required bool isOut, bool isCompact = false}) {
    return IntegrityBadge(
      icon: isOut ? Icons.logout_rounded : Icons.login_rounded,
      label: isOut ? 'Flagged Out' : 'Flagged In',
      color: AppTheme.errorColor,
      isCompact: isCompact,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusSmall),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTheme.bodySmall.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: AppTheme.bodySmall.copyWith(
            color: color.withOpacity(0.8),
            fontWeight: FontWeight.w600,
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

