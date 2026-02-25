import 'package:flutter/material.dart';

/// Badge showing inside/outside geofence status for attendance.
class GeofenceStatusBadge extends StatelessWidget {
  final bool inside;
  final double? distanceMeters;

  const GeofenceStatusBadge({
    super.key,
    required this.inside,
    this.distanceMeters,
  });

  @override
  Widget build(BuildContext context) {
    final color = inside ? Colors.green : Colors.orange;
    final text = inside
        ? 'Inside site'
        : (distanceMeters != null
            ? '${distanceMeters!.toStringAsFixed(0)} m away'
            : 'Outside site');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(inside ? Icons.location_on : Icons.location_off,
              size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
