import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_theme.dart';
import '../core/config.dart';

/// Professional geofence verification bottom-sheet shown to students before
/// confirming attendance. Displays site info, GPS, distance, trust score.
class GeofenceVerificationPanel extends StatelessWidget {
  final String? siteName;
  final String? siteAddress;
  final double? siteLatitude;
  final double? siteLongitude;
  final double currentLatitude;
  final double currentLongitude;
  final double? distanceMeters;
  final double? accuracyMeters;
  final bool? insideGeofence;
  final int? trustScore;
  final VoidCallback onProceed;

  const GeofenceVerificationPanel({
    super.key,
    this.siteName,
    this.siteAddress,
    this.siteLatitude,
    this.siteLongitude,
    required this.currentLatitude,
    required this.currentLongitude,
    this.distanceMeters,
    this.accuracyMeters,
    this.insideGeofence,
    this.trustScore,
    required this.onProceed,
  });

  @override
  Widget build(BuildContext context) {
    final inside = insideGeofence ?? true;
    final trust = trustScore ?? 100;
    final canProceed = inside || !GeofenceConfig.blockOutsideGeofence;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: inside
                      ? AppTheme.successColor.withOpacity(0.1)
                      : AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  inside ? Icons.shield_outlined : Icons.shield_outlined,
                  color: inside ? AppTheme.successColor : AppTheme.errorColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Geofence Verification',
                      style: AppTheme.heading3.copyWith(fontSize: 17),
                    ),
                    Text(
                      inside
                          ? 'You are within the authorized area'
                          : 'You are outside the authorized area',
                      style: AppTheme.bodySmall.copyWith(
                        color: inside
                            ? AppTheme.successColor
                            : AppTheme.errorColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // OJT Site
          _InfoRow(
            icon: Icons.business_outlined,
            label: 'OJT Site',
            value: siteName ?? 'N/A',
            valueColor: AppTheme.coordinatorPrimary,
          ),
          if (siteAddress != null && siteAddress!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: 'Address',
              value: siteAddress!,
            ),
          ],
          const SizedBox(height: 10),

          // Current location
          _InfoRow(
            icon: Icons.my_location_outlined,
            label: 'Your Location',
            value:
                '${currentLatitude.toStringAsFixed(6)}, ${currentLongitude.toStringAsFixed(6)}',
          ),
          const SizedBox(height: 10),

          // Distance
          if (distanceMeters != null)
            _InfoRow(
              icon: Icons.straighten_outlined,
              label: 'Distance from Site',
              value: '${distanceMeters!.toStringAsFixed(0)} m',
              valueColor: inside ? AppTheme.successColor : AppTheme.errorColor,
            ),
          const SizedBox(height: 10),

          // Accuracy
          if (accuracyMeters != null)
            _InfoRow(
              icon: Icons.gps_fixed_outlined,
              label: 'GPS Accuracy',
              value: '± ${accuracyMeters!.toStringAsFixed(0)} m',
              valueColor: (accuracyMeters! > 100)
                  ? AppTheme.warningColor
                  : Colors.grey.shade700,
            ),
          const SizedBox(height: 10),

          // Trust score
          _TrustScoreRow(trustScore: trust),
          const SizedBox(height: 20),

          // Geofence Status Badge
          _GeofenceStatusChip(inside: inside, distanceMeters: distanceMeters),

          if (!inside && GeofenceConfig.blockOutsideGeofence) ...[
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.errorColor.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppTheme.errorColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Attendance cannot be submitted outside the designated area.',
                      style: AppTheme.bodySmall
                          .copyWith(color: AppTheme.errorColor),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (accuracyMeters != null && accuracyMeters! > 100) ...[
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppTheme.warningColor.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.gps_not_fixed_outlined,
                      color: AppTheme.warningColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Poor GPS accuracy (${accuracyMeters!.toStringAsFixed(0)} m). Location reading may be imprecise.',
                      style: AppTheme.bodySmall
                          .copyWith(color: AppTheme.warningColor),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              // View on Map button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openInMaps(currentLatitude, currentLongitude),
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('View Map'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Proceed button
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: canProceed ? onProceed : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canProceed
                        ? (inside
                            ? AppTheme.successColor
                            : AppTheme.warningColor)
                        : Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        canProceed
                            ? Icons.camera_alt_outlined
                            : Icons.block_outlined,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(canProceed
                          ? 'Proceed'
                          : 'Blocked'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openInMaps(double lat, double lng) async {
    final uri = Uri.parse('https://maps.google.com/?q=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: Colors.grey.shade500),
        const SizedBox(width: 10),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: AppTheme.bodySmall.copyWith(color: Colors.grey.shade600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTheme.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor ?? Colors.grey.shade800,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}

class _TrustScoreRow extends StatelessWidget {
  final int trustScore;

  const _TrustScoreRow({required this.trustScore});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    if (trustScore >= 80) {
      color = AppTheme.successColor;
      label = 'Verified';
    } else if (trustScore >= 60) {
      color = AppTheme.warningColor;
      label = 'Low Risk';
    } else if (trustScore >= 40) {
      color = Colors.orange;
      label = 'Suspicious';
    } else {
      color = AppTheme.errorColor;
      label = 'High Risk';
    }

    return Row(
      children: [
        Icon(Icons.security_outlined, size: 17, color: Colors.grey.shade500),
        const SizedBox(width: 10),
        SizedBox(
          width: 110,
          child: Text(
            'Trust Score',
            style: AppTheme.bodySmall.copyWith(color: Colors.grey.shade600),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              // Score ring
              SizedBox(
                width: 28,
                height: 28,
                child: CustomPaint(
                  painter: _TrustRingPainter(
                      score: trustScore, color: color),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$trustScore / 100',
                style: AppTheme.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  label,
                  style: AppTheme.bodySmall.copyWith(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrustRingPainter extends CustomPainter {
  final int score;
  final Color color;

  const _TrustRingPainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // Background ring
    paint.color = Colors.grey.shade200;
    canvas.drawCircle(center, radius - 1.5, paint);

    // Score arc
    paint.color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 1.5),
      -math.pi / 2,
      2 * math.pi * (score / 100),
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GeofenceStatusChip extends StatelessWidget {
  final bool inside;
  final double? distanceMeters;

  const _GeofenceStatusChip({required this.inside, this.distanceMeters});

  @override
  Widget build(BuildContext context) {
    final color = inside ? AppTheme.successColor : AppTheme.errorColor;
    final text = inside
        ? 'Inside authorized area'
        : (distanceMeters != null
            ? '${distanceMeters!.toStringAsFixed(0)} m outside area'
            : 'Outside authorized area');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            inside ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: AppTheme.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

