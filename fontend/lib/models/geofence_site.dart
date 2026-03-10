/// Model for an OJT geofence site (work location with lat/lng and radius).
/// Used for attendance check-in geofence validation.
class GeofenceSite {
  final int? id;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final int? companyId;
  final String? companyName;
  final String? address;
  final DateTime? createdAt;

  GeofenceSite({
    this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.companyId,
    this.companyName,
    this.address,
    this.createdAt,
  });

  factory GeofenceSite.fromJson(Map<String, dynamic> json) {
    return GeofenceSite(
      id: json['id'] as int?,
      name: json['name'] as String? ?? '',
      latitude: _toDouble(json['latitude']) ?? 0.0,
      longitude: _toDouble(json['longitude']) ?? 0.0,
      radiusMeters: _toDouble(json['radius_meters']) ?? 100.0,
      companyId: json['company_id'] as int?,
      companyName: json['company_name'] as String?,
      address: json['address'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radius_meters': radiusMeters,
      if (companyId != null) 'company_id': companyId,
      if (companyName != null) 'company_name': companyName,
      if (address != null) 'address': address,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}
