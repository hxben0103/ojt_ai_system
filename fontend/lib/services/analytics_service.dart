import 'package:flutter/foundation.dart';
import 'api_service.dart';

class AnalyticsService {
  /// Fetches coordinator overview analytics for dashboards.
  ///
  /// Backend route: GET /api/analytics/coordinator/overview
  static Future<Map<String, dynamic>> getCoordinatorOverview() async {
    try {
      return await ApiService.get('/analytics/coordinator/overview');
    } catch (e) {
      debugPrint('[AnalyticsService] Failed to fetch coordinator overview: $e');
      throw Exception('Failed to fetch coordinator analytics: $e');
    }
  }
}
