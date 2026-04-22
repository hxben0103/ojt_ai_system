import '../models/competency.dart';
import 'api_service.dart';
import '../core/config.dart';

class CompetencyService {
  // Get all competencies
  static Future<List<Competency>> getAllCompetencies({String? program}) async {
    try {
      String endpoint = '${ApiConfig.dailyTasks}/competencies';
      if (program != null) {
        endpoint += '?program=$program';
      }
      
      final response = await ApiService.get(endpoint);
      
      if (response.containsKey('error')) {
        throw Exception(response['error'].toString());
      }
      
      final List<dynamic> data = response['competencies'] ?? [];
      return data.map((json) => Competency.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch competencies: $e');
    }
  }

  // Update competency point value (Admin only)
  static Future<Competency> updatePointValue(int id, int newValue) async {
    try {
      final response = await ApiService.put(
        '${ApiConfig.dailyTasks}/competencies/$id',
        {
          'pointValue': newValue,
        },
      );
      
      if (response.containsKey('error')) {
        throw Exception(response['error'].toString());
      }
      
      return Competency.fromJson(response['competency']);
    } catch (e) {
      throw Exception('Failed to update competency: $e');
    }
  }
}

