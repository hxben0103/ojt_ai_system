import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config.dart';

class ApiService {
  static String? _token;
  static bool _tokenLoaded = false;
  static const String _tokenKey = 'auth_token';

  static void setToken(String token) {
    _token = token;
    _tokenLoaded = true;
  }

  static void clearToken() {
    _token = null;
    _tokenLoaded = false;
  }

  // Load token from storage if not already loaded
  static Future<void> _ensureTokenLoaded() async {
    if (_tokenLoaded || _token != null) {
      return; // Token already loaded or set
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      if (token != null) {
        _token = token;
        _tokenLoaded = true;
      }
    } catch (e) {
      // If loading fails, continue without token
      print('Warning: Could not load token from storage: $e');
    }
  }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  static Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      // Ensure token is loaded before making request
      await _ensureTokenLoaded();
      
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}$endpoint'),
            headers: _headers,
          )
          .timeout(ApiConfig.timeout);

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> post(
      String endpoint, Map<String, dynamic> data) async {
    try {
      // Ensure token is loaded before making request
      await _ensureTokenLoaded();
      
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}$endpoint'),
            headers: _headers,
            body: jsonEncode(data),
          )
          .timeout(ApiConfig.timeout);

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> put(
      String endpoint, Map<String, dynamic> data) async {
    try {
      // Ensure token is loaded before making request
      await _ensureTokenLoaded();
      
      final response = await http
          .put(
            Uri.parse('${ApiConfig.baseUrl}$endpoint'),
            headers: _headers,
            body: jsonEncode(data),
          )
          .timeout(ApiConfig.timeout);

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      // Ensure token is loaded before making request
      await _ensureTokenLoaded();
      
      final response = await http
          .delete(
            Uri.parse('${ApiConfig.baseUrl}$endpoint'),
            headers: _headers,
          )
          .timeout(ApiConfig.timeout);

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return {'success': true};
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      // For 400 (Bad Request), 401 (Unauthorized), and 404 (Not Found), 
      // return the error response so services can handle validation errors and specific error messages
      if (response.statusCode == 400 || response.statusCode == 401 || response.statusCode == 404) {
        try {
          final errorResponse = jsonDecode(response.body) as Map<String, dynamic>;
          // Return the error response so services can check for 'errors' or 'error' fields
          return errorResponse;
        } catch (e) {
          // If parsing fails, create a structured error response
          String errorMessage = 'Request failed with status ${response.statusCode}';
          if (response.statusCode == 401) {
            errorMessage = 'Unauthorized: Please log in again';
          } else if (response.statusCode == 404) {
            errorMessage = 'Resource not found';
          }
          return {'error': errorMessage};
        }
      } else {
        // For other errors (500, etc.), throw exception
        try {
          final error = jsonDecode(response.body) as Map<String, dynamic>;
          // Handle nested error object structure
          if (error.containsKey('error')) {
            final errorObj = error['error'];
            if (errorObj is Map) {
              throw Exception(errorObj['message'] ?? 'Request failed');
            } else if (errorObj is String) {
              throw Exception(errorObj);
            }
          }
          throw Exception(error['error'] ?? 'Request failed');
        } catch (e) {
          if (e is Exception) {
            rethrow;
          }
          throw Exception('Request failed with status ${response.statusCode}');
        }
      }
    }
  }
}

