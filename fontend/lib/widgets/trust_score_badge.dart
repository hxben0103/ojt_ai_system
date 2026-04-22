import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class TrustScoreBadge extends StatelessWidget {
  final int? trustScore;
  final List<String> trustFlags;
  // Fallbacks for specific integrity checks 
  final bool insideGeofence;
  final bool photoPresent;
  final bool isCompact;

  const TrustScoreBadge({
    Key? key,
    required this.trustScore,
    this.trustFlags = const [],
    this.insideGeofence = true,
    this.photoPresent = true,
    this.isCompact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isTrusted = (trustScore ?? 100) >= 70 && trustFlags.isEmpty;
    final bool isSuspicious = (trustScore ?? 100) < 70 || trustFlags.isNotEmpty;
    
    final Color scoreColor = trustScore == null 
        ? Colors.grey.shade600 
        : (isTrusted ? AppTheme.successColor : (isSuspicious ? AppTheme.errorColor : AppTheme.warningColor));
        
    final String scoreText = trustScore == null 
        ? "Trust Score unavailable" 
        : (isSuspicious ? "⚠ Trust Score: $trustScore / 100" : "🟡 Trust Score: $trustScore / 100");

    if (isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: scoreColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: scoreColor.withOpacity(0.5)),
        ),
        child: Text(
          scoreText,
          style: AppTheme.bodySmall.copyWith(
            color: scoreColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        boxShadow: const [AppTheme.cardShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security, color: AppTheme.studentPrimary, size: 20),
              const SizedBox(width: AppTheme.spacing8),
              Text('Attendance Integrity', style: AppTheme.heading3),
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
          
          _IntegrityItem(
            label: insideGeofence ? "Location: Verified" : "Location: Outside Assigned Area",
            isVerified: insideGeofence,
          ),
          const SizedBox(height: AppTheme.spacing4),
          
          _IntegrityItem(
            label: photoPresent ? "Photo Evidence: Verified" : "Photo Evidence: Missing",
            isVerified: photoPresent,
            isWarningOnly: !photoPresent, // Missing photo isn't always a strict failure dynamically 
          ),
          const SizedBox(height: AppTheme.spacing12),
          
          Text(
            scoreText,
            style: AppTheme.bodyMedium.copyWith(
              color: scoreColor,
              fontWeight: FontWeight.bold,
            ),
          ),

          if (trustFlags.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacing8),
            Text(
              "Flags:",
              style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold),
            ),
            ...trustFlags.map((f) => Text("• $f", style: AppTheme.bodySmall)),
          ]
        ],
      ),
    );
  }
}

class _IntegrityItem extends StatelessWidget {
  final String label;
  final bool isVerified;
  final bool isWarningOnly;

  const _IntegrityItem({
    required this.label, 
    required this.isVerified,
    this.isWarningOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor = isVerified 
        ? AppTheme.successColor 
        : (isWarningOnly ? AppTheme.warningColor : AppTheme.errorColor);
        
    final IconData statusIcon = isVerified 
        ? Icons.check_circle 
        : (isWarningOnly ? Icons.info_outline : Icons.cancel);

    return Row(
      children: [
        Icon(
          statusIcon,
          color: statusColor,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTheme.bodyMedium.copyWith(
            color: isVerified ? Colors.grey[800] : statusColor,
          ),
        ),
      ],
    );
  }
}

