import '../core/config.dart';
import '../models/geofence_site.dart';
import 'api_service.dart';

/// Fetches OJT geofence sites from the backend. Used for attendance geofence check.
class OjtSitesService {
  /// Get sites for a company by id. Returns empty list if endpoint missing or error.
  static Future<List<GeofenceSite>> getSitesByCompanyId(int? companyId) async {
    try {
      final query = companyId != null ? '?companyId=$companyId' : '';
      final response = await ApiService.get('${ApiConfig.ojtSites}$query');
      return _parseSitesList(response);
    } catch (e) {
      return [];
    }
  }

  /// Get sites for a company by name (e.g. from student's OJT record).
  /// Returns empty list if no endpoint or error; backward compatible.
  static Future<List<GeofenceSite>> getSitesByCompanyName(String? companyName) async {
    if (companyName == null || companyName.isEmpty) return [];
    try {
      final response = await ApiService.get(
        '${ApiConfig.ojtSites}?company_name=${Uri.encodeComponent(companyName)}',
      );
      return _parseSitesList(response);
    } catch (e) {
      return [];
    }
  }

  static List<GeofenceSite> _parseSitesList(Map<String, dynamic> response) {
    final list = response['sites'] ?? response['ojt_sites'] ?? response;
    if (list is! List) return [];
    return list
        .map((e) => GeofenceSite.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Get a single site by id.
  static Future<GeofenceSite?> getSiteById(int id) async {
    try {
      final response = await ApiService.get('${ApiConfig.ojtSites}/$id');
      final data = response['site'] ?? response;
      if (data is! Map) return null;
      return GeofenceSite.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      return null;
    }
  }
}

