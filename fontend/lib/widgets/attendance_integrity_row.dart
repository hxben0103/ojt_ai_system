import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import 'integrity_badge.dart';

/// A compact row of attendance integrity badges.
/// Uses the standardized IntegrityBadge widget for consistency.
class AttendanceIntegrityRow extends StatelessWidget {
  final bool insideGeofence;
  final bool photoVerified;
  final int flaggedCount;

  const AttendanceIntegrityRow({
    super.key,
    required this.insideGeofence,
    required this.photoVerified,
    this.flaggedCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: const [AppTheme.cardShadow],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IntegrityBadge.geofence(inside: insideGeofence),
          _verticalDivider(),
          IntegrityBadge.photo(verified: photoVerified),
          if (flaggedCount > 0) ...[
            _verticalDivider(),
            IntegrityBadge.trust(flaggedCount: flaggedCount),
          ],
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      height: 36,
      color: Colors.grey[100],
    );
  }
}
