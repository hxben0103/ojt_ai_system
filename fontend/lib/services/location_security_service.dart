import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/location_evidence.dart';
import '../models/trust_result.dart';

const _kLastLat = 'location_security_last_lat';
const _kLastLng = 'location_security_last_lng';
const _kLastTimestamp = 'location_security_last_ts';

/// Trust scoring: (a) Android mock => -60, (b) teleport >200 km/h => -40, (c) accuracy >100m => -20.
/// iOS: skip mock detection; anomaly checks only.
/// Persists last position in SharedPreferences for teleport detection.
class LocationSecurityService {
  static const String _channelName = 'location_security';
  static const MethodChannel _channel = MethodChannel(_channelName);

  /// Call native to check mock location (Android only). Returns false on iOS/web/error.
  static Future<bool> isMockLocationEnabled() async {
    if (kIsWeb) return false;
    try {
      if (!Platform.isAndroid) return false;
      final result = await _channel.invokeMethod<bool>('isMockLocationEnabled');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Evaluate position: trust score 0-100, evidence, and reasons.
  static Future<({TrustResult result, LocationEvidence evidence})> evaluate(
    Position position,
  ) async {
    final flags = <String>[];
    int score = 100;
    final timestamp = position.timestamp ?? DateTime.now();
    double? accuracyMeters = position.accuracy > 0 ? position.accuracy : null;
    final isMock = await isMockLocationEnabled();

    // (a) Android mock => -60
    if (isMock) {
      score -= 60;
      flags.add('mock_location');
    }

    // (b) Teleport: last position exists and implied speed > 200 km/h
    final prefs = await SharedPreferences.getInstance();
    final lastLat = prefs.getDouble(_kLastLat);
    final lastLng = prefs.getDouble(_kLastLng);
    final lastTsStr = prefs.getString(_kLastTimestamp);
    final posTs = position.timestamp;
    if (lastLat != null &&
        lastLng != null &&
        lastTsStr != null &&
        posTs != null) {
      final lastTs = DateTime.tryParse(lastTsStr);
      if (lastTs != null) {
        final distM = _haversineMeters(
          lastLat,
          lastLng,
          position.latitude,
          position.longitude,
        );
        final durationSec = posTs.difference(lastTs).inSeconds.abs();
        if (durationSec > 0) {
          final speedMps = distM / durationSec;
          final speedKmh = speedMps * 3.6;
          if (speedKmh > 200) {
            score -= 40;
            flags.add('teleport_jump');
          }
        }
      }
    }

    // (c) Poor accuracy > 100m => -20
    if (accuracyMeters != null && accuracyMeters > 100) {
      score -= 20;
      flags.add('low_accuracy');
    }

    // Persist current position for next teleport check
    await prefs.setDouble(_kLastLat, position.latitude);
    await prefs.setDouble(_kLastLng, position.longitude);
    await prefs.setString(_kLastTimestamp, timestamp.toIso8601String());

    final finalScore = score.clamp(0, 100);
    final isSuspicious = finalScore < 100 || flags.isNotEmpty;

    final result = TrustResult(
      score: finalScore,
      isSuspicious: isSuspicious,
      reasons: flags,
    );
    final evidence = LocationEvidence(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: accuracyMeters,
      speedMps: position.speed >= 0 ? position.speed : null,
      timestamp: timestamp,
      isMock: isMock ? true : null,
      flags: flags,
    );

    return (result: result, evidence: evidence);
  }

  static double _haversineMeters(
      double lat1, double lon1, double lat2, double lon2) {
    const p = 3.14159265359 / 180;
    final a = 0.5 -
        _cos((lat2 - lat1) * p) / 2 +
        _cos(lat1 * p) *
            _cos(lat2 * p) *
            (1 - _cos((lon2 - lon1) * p)) /
            2;
    return 12742000 * _asin(_sqrt(a));
  }

  static double _cos(double x) {
    if (x.isNaN) return 0;
    x = x % (2 * 3.14159265359);
    if (x > 3.14159265359) x -= 2 * 3.14159265359;
    final x2 = x * x;
    return 1 - x2 / 2 + x2 * x2 / 24;
  }

  static double _asin(double x) {
    if (x <= -1) return -1.57079632679;
    if (x >= 1) return 1.57079632679;
    return x + x * x * x / 6;
  }

  static double _sqrt(double x) {
    if (x <= 0) return 0;
    double s = x;
    for (var i = 0; i < 10; i++) {
      s = (s + x / s) / 2;
    }
    return s;
  }
}

