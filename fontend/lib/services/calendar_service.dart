import '../core/config.dart';
import 'api_service.dart';

class CalendarService {
  // Get all calendar events
  static Future<List<Map<String, dynamic>>> getEvents({int? year}) async {
    try {
      String endpoint = '/calendar';
      if (year != null) endpoint += '?year=$year';
      final response = await ApiService.get(endpoint);
      final List<dynamic> data = response['events'] ?? [];
      return data.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      throw Exception('Failed to fetch calendar events: $e');
    }
  }

  // Check if a date is blocked
  static Future<Map<String, dynamic>> isDateBlocked(String date) async {
    try {
      final response = await ApiService.get('/calendar/is-blocked?date=$date');
      return response;
    } catch (e) {
      return {'blocked': false};
    }
  }

  // Create a new calendar event (Admin only)
  static Future<Map<String, dynamic>> createEvent({
    required String title,
    required String eventType,
    required String startDate,
    required String endDate,
    bool isRecurring = false,
  }) async {
    try {
      final response = await ApiService.post('/calendar', {
        'title': title,
        'event_type': eventType,
        'start_date': startDate,
        'end_date': endDate,
        'is_recurring': isRecurring,
      });
      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }
      return response;
    } catch (e) {
      throw Exception('Failed to create event: $e');
    }
  }

  // Delete a calendar event (Admin only)
  static Future<void> deleteEvent(int eventId) async {
    try {
      final response = await ApiService.delete('/calendar/$eventId');
      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }
    } catch (e) {
      throw Exception('Failed to delete event: $e');
    }
  }
}

