import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../core/app_theme.dart';
import '../../services/api_service.dart';
import '../../models/attendance.dart';

/// Coordinator "God View" - shows all OJT students on a live map today.
/// Green pins = on-site / trusted. Red pulsing pins = flagged / suspicious.
/// Uses OpenStreetMap + Leaflet.js (no API key required).
class CoordinatorLiveMapScreen extends StatefulWidget {
  final int coordinatorId;

  const CoordinatorLiveMapScreen({
    super.key,
    required this.coordinatorId,
  });

  @override
  State<CoordinatorLiveMapScreen> createState() =>
      _CoordinatorLiveMapScreenState();
}

class _CoordinatorLiveMapScreenState
    extends State<CoordinatorLiveMapScreen> {
  InAppWebViewController? _webViewController;
  bool _loading = true;
  String? _error;
  List<_StudentPin> _pins = [];

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    try {
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      
      // Get all attendance for today that this coordinator can see
      final response = await ApiService.get(
          '/attendance?date=$todayStr');
      final attendances =
          (response['attendance'] as List<dynamic>? ?? []);

      final pins = <_StudentPin>[];

      for (final a in attendances) {
        // Find the most recent available GPS coordinates
        double? lat;
        double? lng;

        // Check checkout coordinates first (Out events), then checkin coordinates (In events)
        if (a['checkout_lat'] != null) {
          lat = (a['checkout_lat'] as num).toDouble();
          lng = (a['checkout_lng'] as num).toDouble();
        } else if (a['checkin_lat'] != null) {
          lat = (a['checkin_lat'] as num).toDouble();
          lng = (a['checkin_lng'] as num).toDouble();
        }

        if (lat != null && lng != null) {
          final flags = a['trust_flags'];
          final verificationStatus =
              a['verification_status'] as String? ?? '';
          final isFlagged = verificationStatus == 'FLAGGED' ||
              (flags != null && flags.toString().isNotEmpty);
              
          pins.add(_StudentPin(
            studentName: a['full_name'] as String? ?? 'Student ${a['student_id']}',
            lat: lat,
            lng: lng,
            isFlagged: isFlagged,
            trustScore: (a['trust_score'] as num?)?.toInt() ?? 100,
          ));
        }
      }

      setState(() {
        _pins = pins;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _buildMapHtml() {
    final pinsJson = json.encode(_pins
        .map((p) => {
              'name': p.studentName,
              'lat': p.lat,
              'lng': p.lng,
              'flagged': p.isFlagged,
              'trust': p.trustScore,
            })
        .toList());

    // Default center on Philippines if no pins
    final centerLat = _pins.isNotEmpty
        ? _pins.map((p) => p.lat).reduce((a, b) => a + b) / _pins.length
        : 8.0;
    final centerLng = _pins.isNotEmpty
        ? _pins.map((p) => p.lng).reduce((a, b) => a + b) / _pins.length
        : 124.0;

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"/>
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
  <style>
    body { margin:0; padding:0; }
    #map { width:100%; height:100vh; }
    .pulse-ring { width:20px; height:20px; border-radius:50%; animation:pulse 1.5s infinite; }
    @keyframes pulse {
      0%   { box-shadow: 0 0 0 0 rgba(255,80,80,0.7); }
      70%  { box-shadow: 0 0 0 14px rgba(255,80,80,0); }
      100% { box-shadow: 0 0 0 0 rgba(255,80,80,0); }
    }
  </style>
</head>
<body>
<div id="map"></div>
<script>
  var map = L.map('map').setView([$centerLat, $centerLng], 12);
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '&copy; OpenStreetMap contributors'
  }).addTo(map);

  var pins = $pinsJson;
  pins.forEach(function(p) {
    var color = p.flagged ? '#FF4444' : '#22C55E';
    var icon = L.divIcon({
      className: '',
      html: '<div style="width:18px;height:18px;border-radius:50%;background:' + color + ';border:3px solid white;box-shadow:0 2px 6px rgba(0,0,0,0.4);' + (p.flagged ? 'animation:pulse 1.5s infinite;' : '') + '"></div>',
      iconSize: [18, 18],
      iconAnchor: [9, 9],
    });
    var marker = L.marker([p.lat, p.lng], {icon: icon}).addTo(map);
    var statusText = p.flagged
      ? '<span style="color:#FF4444;font-weight:bold">⚠ FLAGGED</span>'
      : '<span style="color:#22C55E;font-weight:bold">✓ Verified</span>';
    marker.bindPopup(
      '<b>' + p.name + '</b><br>' +
      statusText + '<br>' +
      'Trust Score: ' + p.trust + '/100'
    );
  });
</script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    final flaggedCount = _pins.where((p) => p.isFlagged).length;
    final safeCount = _pins.length - flaggedCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Attendance Map'),
        backgroundColor: AppTheme.coordinatorPrimary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _loading = true);
              _loadAttendance();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Status bar
          if (!_loading && _error == null && _pins.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.grey.shade100,
              child: Row(
                children: [
                  _StatusChip(
                      count: safeCount,
                      label: 'Online',
                      color: const Color(0xFF22C55E)),
                  const SizedBox(width: 12),
                  _StatusChip(
                      count: flaggedCount,
                      label: 'Flagged',
                      color: const Color(0xFFFF4444)),
                  const Spacer(),
                  Text(
                    'Today\'s Check-Ins',
                    style: AppTheme.bodySmall.copyWith(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

          // Map
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.wifi_off,
                                size: 64, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text('Failed to load attendance data',
                                style: AppTheme.bodyMedium),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: () {
                                setState(() => _loading = true);
                                _loadAttendance();
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _pins.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.location_off_outlined,
                                    size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text('No check-ins today',
                                    style: AppTheme.bodyMedium.copyWith(
                                        color: Colors.grey)),
                                const SizedBox(height: 4),
                                Text(
                                  'Students who clock in will appear here',
                                  style: AppTheme.bodySmall.copyWith(
                                      color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          )
                        : InAppWebView(
                            initialData: InAppWebViewInitialData(
                              data: _buildMapHtml(),
                              mimeType: 'text/html',
                              encoding: 'utf-8',
                            ),
                            initialSettings: InAppWebViewSettings(
                              javaScriptEnabled: true,
                              allowFileAccessFromFileURLs: true,
                            ),
                            onWebViewCreated: (controller) {
                              _webViewController = controller;
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _StudentPin {
  final String studentName;
  final double lat;
  final double lng;
  final bool isFlagged;
  final int trustScore;

  _StudentPin({
    required this.studentName,
    required this.lat,
    required this.lng,
    required this.isFlagged,
    required this.trustScore,
  });
}

class _StatusChip extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _StatusChip(
      {required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$count $label',
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12),
          ),
        ],
      ),
    );
  }
}

