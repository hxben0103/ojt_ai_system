import 'dart:math' as math;
import '../models/geofence_site.dart';

/// Geofence check: distance from point to site and inside/outside.
class GeofenceService {
  /// Haversine distance in meters between two lat/lng points.
  static double distanceBetween(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = math.pi / 180;
    final a = 0.5 -
        math.cos((lat2 - lat1) * p) / 2 +
        math.cos(lat1 * p) * math.cos(lat2 * p) * (1 - math.cos((lon2 - lon1) * p)) / 2;
    return 12742000 * math.asin(math.sqrt(a)); // 2 * R * asin; R = 6371000 m
  }

  /// Returns true if (lat, lng) is within site.radiusMeters of the site.
  static bool isInside(GeofenceSite site, double lat, double lng) {
    final d = distanceBetween(site.latitude, site.longitude, lat, lng);
    return d <= site.radiusMeters;
  }

  /// Result of a geofence check for a position.
  static ({bool inside, double distanceMeters}) check(
    GeofenceSite site,
    double lat,
    double lng,
  ) {
    final distanceMeters =
        distanceBetween(site.latitude, site.longitude, lat, lng);
    final inside = distanceMeters <= site.radiusMeters;
    return (inside: inside, distanceMeters: distanceMeters);
  }
}

