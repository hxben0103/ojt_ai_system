import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'api_service.dart';
import '../core/config.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  // Register user
  static Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final response = await ApiService.post(
        '${ApiConfig.auth}/register',
        {
          'full_name': fullName,
          'email': email,
          'password': password,
          'role': role,
        },
      );

      // Check for error in response (for 400 status codes)
      if (response['error'] != null) {
        throw Exception(response['error']);
      }

      if (response['token'] != null) {
        await _saveToken(response['token']);
        await _saveUser(response['user']);
        ApiService.setToken(response['token']);
      }

      return response;
    } catch (e) {
      // If it's already an Exception with a message, rethrow it
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Registration failed: $e');
    }
  }

  // Login user
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await ApiService.post(
        '${ApiConfig.auth}/login',
        {
          'email': email,
          'password': password,
        },
      );

      if (response['token'] != null) {
        await _saveToken(response['token']);
        await _saveUser(response['user']);
        ApiService.setToken(response['token']);
      }

      return response;
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  // Logout user
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
    ApiService.clearToken();
  }

  // Get current user
  static Future<User?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      
      if (userJson != null) {
        return User.fromJson(
          Map<String, dynamic>.from(
            jsonDecode(userJson),
          ),
        );
      }

      // Try to get from API if token exists
      final token = await getToken();
      if (token != null) {
        ApiService.setToken(token);
        final response = await ApiService.get('${ApiConfig.auth}/profile');
        if (response['user'] != null) {
          final user = User.fromJson(response['user']);
          await _saveUser(response['user']);
          return user;
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // Get stored token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    if (token != null) {
      ApiService.setToken(token);
      return true;
    }
    return false;
  }

  // Save token to storage
  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  // Save user to storage
  static Future<void> _saveUser(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user));
  }
}

