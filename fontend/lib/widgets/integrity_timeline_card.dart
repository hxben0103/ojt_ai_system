import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/attendance.dart';
import '../core/app_theme.dart';
import '../services/attendance_service.dart';

class IntegrityTimelineCard extends StatelessWidget {
  final List<Attendance> attendanceHistory;

  final bool showStudent;

  const IntegrityTimelineCard({
    Key? key,
    required this.attendanceHistory,
    this.showStudent = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (attendanceHistory.isEmpty) {
      return const SizedBox.shrink();
    }

    final recentEntries = attendanceHistory.take(5).toList();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.shield_outlined,
                    color: AppTheme.coordinatorPrimary, size: 20),
                const SizedBox(width: 8),
                Text(
                  "Integrity Timeline",
                  style:
                      AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade50,
            child: Row(
              children: [
                if (showStudent) Expanded(flex: 3, child: _headerText("Student")),
                Expanded(flex: 2, child: _headerText("Date")),
                Expanded(flex: 2, child: _headerText("Geofence")),
                Expanded(flex: 2, child: _headerText("Trust")),
                Expanded(flex: 2, child: _headerText("Photo")),
                Expanded(flex: 2, child: _headerText("Dist.")),
                const SizedBox(width: 28), // map icon space
              ],
            ),
          ),
          const Divider(height: 1),
          // Rows
          ...recentEntries
              .map((a) => _buildRow(context, a)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _headerText(String text) {
    return Text(
      text,
      style: AppTheme.bodySmall.copyWith(
        color: Colors.grey.shade600,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildRow(BuildContext context, Attendance attendance) {
    // Geofence
    final bool isInside = attendance.insideGeofence ?? true;
    final String geofenceText = isInside ? "Inside" : "Outside";
    final Color geofenceColor =
        isInside ? AppTheme.successColor : AppTheme.errorColor;

    // Trust score + classification
    final int trustScore = attendance.trustScore ?? 100;
    final Color trustColor;
    final String trustLabel;
    if (trustScore >= 80) {
      trustColor = AppTheme.successColor;
      trustLabel = "$trustScore ✓";
    } else if (trustScore >= 60) {
      trustColor = AppTheme.warningColor;
      trustLabel = "$trustScore ⚡";
    } else if (trustScore >= 40) {
      trustColor = Colors.orange;
      trustLabel = "$trustScore ⚠";
    } else {
      trustColor = AppTheme.errorColor;
      trustLabel = "$trustScore ✗";
    }

    // Photo availability
    final bool hasPhoto = attendance.checkinPhotoPath != null ||
        attendance.attendanceImage != null ||
        (attendance.hasBase64Image ?? false);

    // Location availability
    // Location availability (either checkin or checkout)
    final bool hasLocation = (attendance.checkinLat != null && attendance.checkinLng != null) ||
        (attendance.checkoutLat != null && attendance.checkoutLng != null);

    final DateFormat formatter = DateFormat('MMM dd, yyyy');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          if (showStudent)
            Expanded(
              flex: 3,
              child: Text(
                attendance.studentName ?? 'Unknown',
                style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          // Date
          Expanded(
            flex: 2,
            child: Text(
              formatter.format(attendance.date),
              style: AppTheme.bodySmall.copyWith(color: Colors.grey.shade800, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Geofence badge
          Expanded(
            flex: 2,
            child: _buildBadge(geofenceText, geofenceColor),
          ),
          // Trust badge
          Expanded(
            flex: 2,
            child: _buildBadge(trustLabel, trustColor),
          ),
          // Photo link
          Expanded(
            flex: 2,
            child: hasPhoto
                ? GestureDetector(
                    onTap: () => _showPhotoDialog(context, attendance),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.image_outlined,
                            size: 15, color: Colors.blue.shade600),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            "View",
                            style: AppTheme.bodySmall.copyWith(
                              color: Colors.blue.shade600,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )
                : Text(
                    "—",
                    style: AppTheme.bodySmall.copyWith(
                      color: Colors.grey.shade400,
                      fontSize: 10,
                    ),
                  ),
          ),
          // Distance
          Expanded(
            flex: 2,
            child: Text(
              "N/A", // Distance native
              style: AppTheme.bodySmall.copyWith(color: Colors.grey.shade600, fontSize: 10),
            ),
          ),
          // Map icon (tappable when location exists)
          SizedBox(
            width: 28,
            child: hasLocation
                ? GestureDetector(
                    onTap: () => _openInMaps(
                      attendance.checkoutLat ?? attendance.checkinLat!,
                      attendance.checkoutLng ?? attendance.checkinLng!,
                    ),
                    child: Tooltip(
                      message: 'View location on map',
                      child: Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: Colors.blue.shade400,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
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

    void _showPhotoDialog(BuildContext context, Attendance attendance) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "Photo — ${DateFormat('MMM dd, yyyy').format(attendance.date)}",
                      style: AppTheme.bodyLarge
                          .copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
                maxWidth: MediaQuery.of(context).size.width * 0.9,
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16)),
                child: _buildImageLoader(attendance),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildImageLoader(Attendance attendance) {
    if (attendance.attendanceImage != null &&
        attendance.attendanceImage!.isNotEmpty) {
      return _buildMemoryImage(attendance.attendanceImage!);
    } else if (attendance.checkinPhotoPath != null &&
        attendance.checkinPhotoPath!.isNotEmpty) {
      return _buildNetworkImage(attendance.checkinPhotoPath!);
    } else if (attendance.hasBase64Image == true &&
        attendance.attendanceId != null) {
      return FutureBuilder<String?>(
        future: AttendanceService.getAttendanceImage(attendance.attendanceId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: CircularProgressIndicator(),
              ),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return const Center(child: Text("Failed to load photo"));
          }
          return _buildMemoryImage(snapshot.data!);
        },
      );
    } else {
      return const Center(child: Text("No photo available"));
    }
  }

  Widget _buildMemoryImage(String base64Str) {
    try {
      return Image.memory(
        base64Decode(base64Str),
        fit: BoxFit.contain,
      );
    } catch (e) {
      return const Center(child: Text("Error decoding image"));
    }
  }

  Widget _buildNetworkImage(String url) {
    if (url.startsWith('http')) {
      return Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            const Center(child: Text("Failed to load image")),
      );
    } else {
      return Center(child: Text("Photo path: $url"));
    }
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: AppTheme.bodySmall.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
