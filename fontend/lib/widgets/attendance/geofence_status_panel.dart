import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

class GeofenceStatusPanel extends StatelessWidget {
  final bool? isInsideGeofence;
  final String? siteName;
  final String? siteAddress;
  final double? currentLat;
  final double? currentLng;
  final double? distanceToSite;
  final double? gpsAccuracy;

  const GeofenceStatusPanel({
    super.key,
    required this.isInsideGeofence,
    this.siteName,
    this.siteAddress,
    this.currentLat,
    this.currentLng,
    this.distanceToSite,
    this.gpsAccuracy,
  });

  @override
  Widget build(BuildContext context) {
    final bool isOutside = isInsideGeofence == false;
    final Color panelColor = isOutside ? AppTheme.errorColor : AppTheme.successColor;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: panelColor),
                const SizedBox(width: 8),
                Text("Geofence Verification", style: AppTheme.heading3),
                const Spacer(),
                if (isInsideGeofence != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: panelColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isInsideGeofence! ? "Verified" : "Outside Area",
                      style: TextStyle(
                        color: panelColor, 
                        fontWeight: FontWeight.bold, 
                        fontSize: 10
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: AppTheme.spacing12),
            Text(
              siteName ?? "Loading site details...", 
              style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold)
            ),
            Text(
              siteAddress ?? "Checking location...", 
              style: AppTheme.bodySmall
            ),
            SizedBox(height: AppTheme.spacing12),
            if (currentLat != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildLocationInfo("Coordinates", "${currentLat!.toStringAsFixed(4)}, ${currentLng!.toStringAsFixed(4)}"),
                  _buildLocationInfo("Distance", distanceToSite != null ? "${distanceToSite!.toStringAsFixed(1)}m" : "N/A"),
                  _buildLocationInfo("Accuracy", gpsAccuracy != null ? "\u00b1${gpsAccuracy!.toStringAsFixed(1)}m" : "N/A"),
                ],
              ),
            ],
            if (isOutside) ...[
              SizedBox(height: AppTheme.spacing12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppTheme.errorColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "You are outside the authorized OJT site. Attendance cannot be submitted.",
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.errorColor, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        Text(value, style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
