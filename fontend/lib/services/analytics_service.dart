import 'package:flutter/foundation.dart';
import 'api_service.dart';

class AnalyticsService {
  /// Fetches coordinator overview analytics for dashboards.
  ///
  /// Backend route: GET /api/analytics/coordinator/overview?coordinator_id=...
  static Future<Map<String, dynamic>> getCoordinatorOverview({int? coordinatorId}) async {
    try {
      final String endpoint = coordinatorId != null
          ? '/analytics/coordinator/overview?coordinator_id=$coordinatorId'
          : '/analytics/coordinator/overview';
      return await ApiService.get(endpoint);
    } catch (e) {
      debugPrint('[AnalyticsService] Failed to fetch coordinator overview: $e');
      throw Exception('Failed to fetch coordinator analytics: $e');
    }
  }
}

