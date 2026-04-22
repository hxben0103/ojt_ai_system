/// Evidence snapshot for a single location reading (used for trust scoring).
class LocationEvidence {
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final double? speedMps;
  final DateTime timestamp;
  final bool? isMock;
  final List<String> flags;

  LocationEvidence({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
    this.speedMps,
    required this.timestamp,
    this.isMock,
    this.flags = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      if (accuracyMeters != null) 'accuracy_meters': accuracyMeters,
      if (speedMps != null) 'speed_mps': speedMps,
      'timestamp': timestamp.toIso8601String(),
      if (isMock != null) 'is_mock': isMock,
      'flags': flags,
    };
  }
}

