import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_theme.dart';
import '../../models/attendance.dart';
import '../../models/geofence_site.dart';
import '../../services/geofence_service.dart';
import '../../services/ojt_sites_service.dart';

/// Coordinator-facing screen that shows geofence evidence for an attendance
/// record. Uses a static map image + Google Maps link (no native Maps SDK
/// required — avoids needing an API key / google_maps_flutter dependency).
class CoordinatorAttendanceMapScreen extends StatefulWidget {
  final Attendance attendance;
  final String? companyName;

  const CoordinatorAttendanceMapScreen({
    super.key,
    required this.attendance,
    this.companyName,
  });

  @override
  State<CoordinatorAttendanceMapScreen> createState() =>
      _CoordinatorAttendanceMapScreenState();
}

class _CoordinatorAttendanceMapScreenState
    extends State<CoordinatorAttendanceMapScreen> {
  GeofenceSite? _site;
  double? _distanceM;
  bool? _insideGeofence;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSiteAndDistance();
  }

  Future<void> _loadSiteAndDistance() async {
    final lat = widget.attendance.checkinLat;
    final lng = widget.attendance.checkinLng;

    if (lat == null || lng == null) {
      setState(() {
        _loading = false;
        _error = 'No check-in location recorded for this attendance.';
      });
      return;
    }

    try {
      GeofenceSite? nearest;
      double? distance;
      bool? inside;

      if (widget.companyName != null && widget.companyName!.isNotEmpty) {
        final sites =
            await OjtSitesService.getSitesByCompanyName(widget.companyName);
        if (sites.isNotEmpty) {
          nearest = sites.first;
          var best = GeofenceService.check(nearest, lat, lng);
          for (var i = 1; i < sites.length; i++) {
            final check = GeofenceService.check(sites[i], lat, lng);
            if (check.distanceMeters < best.distanceMeters) {
              nearest = sites[i];
              best = check;
            }
          }
          distance = best.distanceMeters;
          inside = best.inside;
        }
      }

      if (mounted) {
        setState(() {
          _site = nearest;
          _distanceM = distance;
          _insideGeofence =
              inside ?? widget.attendance.insideGeofence;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load site information.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show checkout location if available, otherwise checkin location
    final lat = widget.attendance.checkoutLat ?? widget.attendance.checkinLat;
    final lng = widget.attendance.checkoutLng ?? widget.attendance.checkinLng;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Location Evidence'),
        backgroundColor: AppTheme.coordinatorPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: AppTheme.surfaceColor,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (lat == null || lng == null)
              ? _buildNoLocation()
              : _buildContent(lat, lng),
    );
  }

  Widget _buildNoLocation() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_outlined,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              _error ?? 'No location data for this attendance record.',
              style: AppTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(double lat, double lng) {
    final inside = _insideGeofence ?? widget.attendance.insideGeofence ?? true;
    final trust = widget.attendance.trustScore;

    final Color geofenceColor =
        inside ? AppTheme.successColor : AppTheme.errorColor;
    final String geofenceLabel =
        inside ? 'Inside authorized area' : 'Outside authorized area';

    Color trustColor;
    String trustLabel;
    if (trust == null) {
      trustColor = Colors.grey;
      trustLabel = 'N/A';
    } else if (trust >= 80) {
      trustColor = AppTheme.successColor;
      trustLabel = '$trust / 100 — Verified';
    } else if (trust >= 60) {
      trustColor = AppTheme.warningColor;
      trustLabel = '$trust / 100 — Low Risk';
    } else if (trust >= 40) {
      trustColor = Colors.orange;
      trustLabel = '$trust / 100 — Suspicious';
    } else {
      trustColor = AppTheme.errorColor;
      trustLabel = '$trust / 100 — High Risk';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Static map preview card ──────────────────────────────────
          _StaticMapCard(
            studentLat: lat,
            studentLng: lng,
            siteLat: _site?.latitude,
            siteLng: _site?.longitude,
          ),
          const SizedBox(height: 16),

          // ── Evidence card ────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [AppTheme.cardShadow],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_outlined,
                        color: AppTheme.coordinatorPrimary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Geofence Evidence',
                      style: AppTheme.bodyLarge
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Site info
                if (_site != null) ...[
                  _EvidenceRow(
                    icon: Icons.business_outlined,
                    label: 'OJT Site',
                    value: _site!.name,
                    valueColor: AppTheme.coordinatorPrimary,
                  ),
                  const SizedBox(height: 8),
                  if (_site!.address != null && _site!.address!.isNotEmpty)
                    _EvidenceRow(
                      icon: Icons.location_city_outlined,
                      label: 'Address',
                      value: _site!.address!,
                    ),
                  const SizedBox(height: 8),
                ],

                // Student coordinates
                _EvidenceRow(
                  icon: Icons.my_location_outlined,
                  label: 'Check-in GPS',
                  value:
                      '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                ),
                const SizedBox(height: 8),

                // Distance
                if (_distanceM != null)
                  _EvidenceRow(
                    icon: Icons.straighten_outlined,
                    label: 'Distance',
                    value: '${_distanceM!.toStringAsFixed(0)} m from site',
                    valueColor: geofenceColor,
                  ),
                const SizedBox(height: 8),



                // Status pills
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildPill(geofenceLabel, geofenceColor),
                    _buildPill('Trust: $trustLabel', trustColor),
                  ],
                ),

                const SizedBox(height: 14),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            _openStudentInMaps(lat, lng),
                        icon: const Icon(Icons.person_pin_circle_outlined,
                            size: 18),
                        label: const Text('Student Location'),
                        style: OutlinedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    if (_site != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openSiteInMaps(
                              _site!.latitude, _site!.longitude),
                          icon: const Icon(Icons.business_outlined,
                              size: 18),
                          label: const Text('OJT Site'),
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // ── Trust flags (if any) ──────────────────────────────────
          _buildTrustFlags(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildTrustFlags() {
    final raw = widget.attendance.trustFlags;
    if (raw == null || raw.isEmpty) return const SizedBox.shrink();

    List<String> flags;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        flags = decoded.map((e) => e.toString()).toList();
      } else {
        flags = [raw];
      }
    } catch (_) {
      flags = [raw];
    }

    if (flags.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.warningColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.warningColor.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.flag_outlined,
                      size: 16, color: AppTheme.warningColor),
                  const SizedBox(width: 6),
                  Text(
                    'Trust Flags',
                    style: AppTheme.bodySmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.warningColor),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...flags.map(
                (flag) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.circle,
                          size: 5,
                          color: AppTheme.warningColor.withOpacity(0.6)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          flag,
                          style: AppTheme.bodySmall
                              .copyWith(color: Colors.grey.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: AppTheme.bodySmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _openStudentInMaps(double lat, double lng) async {
    final uri = Uri.parse('https://maps.google.com/?q=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openSiteInMaps(double lat, double lng) async {
    final uri = Uri.parse('https://maps.google.com/?q=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ── Static map card using Google Static Maps (no SDK needed) ─────────────────

class _StaticMapCard extends StatelessWidget {
  final double studentLat;
  final double studentLng;
  final double? siteLat;
  final double? siteLng;

  const _StaticMapCard({
    required this.studentLat,
    required this.studentLng,
    this.siteLat,
    this.siteLng,
  });

  @override
  Widget build(BuildContext context) {
    // Build a Google Static Maps URL (no API key version — limited but works
    // for demonstration; coordinators can click through to Maps app)
    final studentMarker =
        'color:green%7Clabel:S%7C$studentLat,$studentLng';
    final siteMarker = (siteLat != null && siteLng != null)
        ? 'color:blue%7Clabel:W%7C$siteLat,$siteLng'
        : null;

    final center = (siteLat != null && siteLng != null)
        ? '${((studentLat + siteLat!) / 2)},${((studentLng + siteLng!) / 2)}'
        : '$studentLat,$studentLng';

    String mapUrl =
        'https://maps.googleapis.com/maps/api/staticmap?center=$center&zoom=15&size=600x300&scale=2'
        '&markers=$studentMarker';
    if (siteMarker != null) {
      mapUrl += '&markers=$siteMarker';
    }

    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          // Map placeholder with coordinate display (static map loads if API key added)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.map_outlined, size: 48, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                Text(
                  'Student Check-in Location',
                  style: AppTheme.bodySmall.copyWith(
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '${studentLat.toStringAsFixed(5)}, ${studentLng.toStringAsFixed(5)}',
                  style:
                      AppTheme.bodySmall.copyWith(color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
          // Legend overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.4),
                  ],
                ),
              ),
              child: Row(
                children: [
                  _LegendDot(color: Colors.green, label: 'Student GPS'),
                  if (siteLat != null) ...[
                    const SizedBox(width: 12),
                    _LegendDot(color: Colors.blue, label: 'OJT Site'),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
              color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// ── Reusable row widget ───────────────────────────────────────────────────────

class _EvidenceRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _EvidenceRow({
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
        Icon(icon, size: 16, color: Colors.grey.shade400),
        const SizedBox(width: 10),
        SizedBox(
          width: 100,
          child: Text(
            label,
            style:
                AppTheme.bodySmall.copyWith(color: Colors.grey.shade600),
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
