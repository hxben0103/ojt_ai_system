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
                Expanded(flex: 2, child: _headerText("OT In")),
                Expanded(flex: 2, child: _headerText("OT Out")),
                Expanded(flex: 2, child: _headerText("Geofence")),
                Expanded(flex: 2, child: _headerText("Trust")),
                Expanded(flex: 2, child: _headerText("In 📷")),
                Expanded(flex: 2, child: _headerText("Out 📷")),
                Expanded(flex: 2, child: _headerText("Dist.")),
                SizedBox(width: 28, child: _headerText("Loc.")), 
              ],
            ),
          ),
          const Divider(height: 1),
          // Rows
          if (attendanceHistory.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  "No recent activity detected",
                  style: AppTheme.bodySmall.copyWith(color: Colors.grey.shade400),
                ),
              ),
            )
          else
            ...attendanceHistory
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

    // Photo availability — check-in photo (attendance_image)
    final bool hasCheckinPhoto = attendance.checkinPhotoPath != null ||
        attendance.photoUrl != null ||
        attendance.attendanceImage != null ||
        (attendance.hasBase64Image ?? false);

    // Photo availability — check-out photo (checkout_image)
    final bool hasCheckoutPhoto = attendance.checkoutPhotoPath != null ||
        attendance.checkoutPhotoUrl != null ||
        attendance.checkoutImage != null ||
        (attendance.hasCheckoutImage ?? false);

    // Location availability (either checkin or checkout)
    final bool hasLocation = (attendance.checkinLat != null && attendance.checkinLng != null) ||
        (attendance.checkoutLat != null && attendance.checkoutLng != null);

    final DateFormat formatter = DateFormat('MMM dd, yyyy');

    // Overtime display
    final String otInText = _formatTimeShort(attendance.overtimeIn);
    final String otOutText = _formatTimeShort(attendance.overtimeOut);
    final bool hasOvertime = attendance.overtimeIn != null;

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
          // OT In
          Expanded(
            flex: 2,
            child: Text(
              otInText,
              style: AppTheme.bodySmall.copyWith(
                color: hasOvertime ? Colors.deepPurple : Colors.grey.shade400,
                fontSize: 10,
                fontWeight: hasOvertime ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          // OT Out
          Expanded(
            flex: 2,
            child: Text(
              otOutText,
              style: AppTheme.bodySmall.copyWith(
                color: attendance.overtimeOut != null ? Colors.deepPurple : Colors.grey.shade400,
                fontSize: 10,
                fontWeight: attendance.overtimeOut != null ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          // Geofence badge
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildBadge(geofenceText, geofenceColor),
            ),
          ),
          // Trust badge
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildBadge(trustLabel, trustColor),
            ),
          ),
          // Check-in Photo (In 📷)
          Expanded(
            flex: 2,
            child: hasCheckinPhoto
                ? GestureDetector(
                    onTap: () => _showPhotoDialog(context, attendance, isCheckout: false),
                    child: Center(
                      child: _buildPhotoThumb(Colors.blue),
                    ),
                  )
                : Center(
                    child: Text(
                      "None",
                      style: AppTheme.bodySmall.copyWith(color: Colors.grey.shade400, fontSize: 10),
                    ),
                  ),
          ),
          // Check-out Photo (Out 📷)
          Expanded(
            flex: 2,
            child: hasCheckoutPhoto
                ? GestureDetector(
                    onTap: () => _showPhotoDialog(context, attendance, isCheckout: true),
                    child: Center(
                      child: _buildPhotoThumb(Colors.orange),
                    ),
                  )
                : Center(
                    child: Text(
                      "None",
                      style: AppTheme.bodySmall.copyWith(color: Colors.grey.shade400, fontSize: 10),
                    ),
                  ),
          ),
          // Distance
          Expanded(
            flex: 2,
            child: Text(
              attendance.distanceM != null ? "${attendance.distanceM!.toStringAsFixed(0)}m" : "N/A",
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
                : Tooltip(
                    message: 'Location data not captured',
                    child: Icon(
                      Icons.location_off_outlined,
                      size: 18,
                      color: Colors.grey.shade300,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoThumb(Color borderColor) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey.shade100,
        border: Border.all(color: borderColor.withOpacity(0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.15),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Icon(Icons.photo_camera, size: 16, color: borderColor),
    );
  }

  Future<void> _openInMaps(double lat, double lng) async {
    final uri = Uri.parse('https://maps.google.com/?q=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

    void _showPhotoDialog(BuildContext context, Attendance attendance, {bool isCheckout = false}) {
    final String photoLabel = isCheckout ? "Check-out Photo" : "Check-in Photo";
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
                      "$photoLabel — ${DateFormat('MMM dd, yyyy').format(attendance.date)}",
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
                child: isCheckout
                    ? _buildCheckoutImageLoader(attendance)
                    : _buildImageLoader(attendance),
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
    } else if (attendance.photoUrl != null &&
        attendance.photoUrl!.isNotEmpty) {
      return _buildNetworkImage(attendance.photoUrl!);
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

  /// Loads the checkout image (from checkout_image column)
  Widget _buildCheckoutImageLoader(Attendance attendance) {
    if (attendance.checkoutImage != null &&
        attendance.checkoutImage!.isNotEmpty) {
      return _buildMemoryImage(attendance.checkoutImage!);
    } else if (attendance.checkoutPhotoUrl != null &&
        attendance.checkoutPhotoUrl!.isNotEmpty) {
      return _buildNetworkImage(attendance.checkoutPhotoUrl!);
    } else if (attendance.checkoutPhotoPath != null &&
        attendance.checkoutPhotoPath!.isNotEmpty) {
      return _buildNetworkImage(attendance.checkoutPhotoPath!);
    } else if (attendance.hasCheckoutImage == true &&
        attendance.attendanceId != null) {
      return FutureBuilder<String?>(
        future: AttendanceService.getCheckoutImage(attendance.attendanceId!),
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
      return const Center(child: Text("No checkout photo"));
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

  /// Format a time string (HH:MM:SS) to short AM/PM format
  String _formatTimeShort(String? time) {
    if (time == null || time.isEmpty) return "-";
    try {
      final parts = time.split(':');
      if (parts.length < 2) return time;
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);
      final period = hour >= 12 ? "PM" : "AM";
      hour = hour % 12;
      if (hour == 0) hour = 12;
      return "$hour:${minute.toString().padLeft(2, '0')} $period";
    } catch (e) {
      return time ?? "-";
    }
  }
}

