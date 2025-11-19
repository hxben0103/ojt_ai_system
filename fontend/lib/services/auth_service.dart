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
    String? studentId,
    String? course,
    int? age,
    String? gender,
    String? contactNumber,
    String? address,
    int? requiredHours,
    String? profilePhoto,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'full_name': fullName,
        'email': email,
        'password': password,
        'role': role,
      };
      
      // Add optional fields - send all fields even if empty, backend will handle null conversion
      // This ensures all data is sent to the backend
      data['student_id'] = studentId;
      data['course'] = course;
      data['age'] = age;
      data['gender'] = gender;
      data['contact_number'] = contactNumber;
      data['address'] = address;
      data['required_hours'] = requiredHours;
      data['profile_photo'] = profilePhoto;
      
      final response = await ApiService.post(
        '${ApiConfig.auth}/register',
        data,
      );

      // Check for error in response (for 400 status codes)
      if (response['error'] != null) {
        throw Exception(response['error']);
      }

      // Only save token if user is approved (status is Active)
      if (response['token'] != null && response['user'] != null) {
        await _saveToken(response['token']);
        await _saveUser(response['user']);
        ApiService.setToken(response['token']);
      } else if (response['user'] != null) {
        // Save user data even if pending (so they can see their status)
        await _saveUser(response['user']);
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

      // Check for error in response (for 400/403 status codes)
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
      throw Exception('Login failed: $e');
    }
  }

  // Logout user
  static Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userKey);
    } catch (e) {
      print('Warning: Could not clear SharedPreferences: $e');
    }
    ApiService.clearToken();
  }

  // Get current user
  static Future<User?> getCurrentUser() async {
    try {
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
      } catch (e) {
        // SharedPreferences might fail on web, continue to API fallback
        print('Warning: Could not read from SharedPreferences: $e');
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
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_tokenKey);
    } catch (e) {
      // On web, SharedPreferences might fail
      print('Warning: Could not read token from SharedPreferences: $e');
      return null;
    }
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
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
    } catch (e) {
      // On web, SharedPreferences might fail, use localStorage fallback
      // For now, just log the error - token will be stored in memory via ApiService.setToken
      print('Warning: Could not save token to SharedPreferences: $e');
    }
  }

  // Save user to storage
  static Future<void> _saveUser(Map<String, dynamic> user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(user));
    } catch (e) {
      // On web, SharedPreferences might fail
      print('Warning: Could not save user to SharedPreferences: $e');
    }
  }

  // Get all users (admin view)
  static Future<List<User>> getAllUsers() async {
    try {
      final response = await ApiService.get('${ApiConfig.auth}/users');
      final List<dynamic> data = response['users'] ?? [];
      return data.map((json) => User.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch users: $e');
    }
  }

  // Get pending users (admins see coordinators, coordinators see students/supervisors)
  static Future<List<User>> getPendingUsers() async {
    try {
      final response = await ApiService.get('${ApiConfig.auth}/pending');
      final List<dynamic> data = response['pendingUsers'] ?? [];
      return data.map((json) => User.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch pending users: $e');
    }
  }

  // Approve user
  static Future<void> approveUser(int userId) async {
    try {
      final response = await ApiService.put(
        '${ApiConfig.auth}/approve/$userId',
        {},
      );
      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }
    } catch (e) {
      throw Exception('Failed to approve user: $e');
    }
  }

  // Reject user
  static Future<void> rejectUser(int userId) async {
    try {
      final response = await ApiService.put(
        '${ApiConfig.auth}/reject/$userId',
        {},
      );
      if (response.containsKey('error')) {
        throw Exception(response['error']);
      }
    } catch (e) {
      throw Exception('Failed to reject user: $e');
    }
  }
}

