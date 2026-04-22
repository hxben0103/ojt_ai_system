import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../core/dio_client.dart';

class ApiService {
  static String? _token;
  static bool _tokenLoaded = false;
  static const String _tokenKey = 'auth_token';
  
  // Expose the configured dio instance from our singleton
  static final Dio _dio = DioClient().dio;

  static void setToken(String token) {
    _token = token;
    _tokenLoaded = true;
    // We optionally keep this in sync, but DioClient loads via SharedPreferences on each request anyway.
    SharedPreferences.getInstance().then((prefs) => prefs.setString(_tokenKey, token));
  }

  static void clearToken() {
    _token = null;
    _tokenLoaded = false;
    SharedPreferences.getInstance().then((prefs) => prefs.remove(_tokenKey));
  }

  static Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final response = await _dio.get(endpoint);
      return _handleResponse(response);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  static Future<Map<String, dynamic>> post(
      String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(endpoint, data: data);
      return _handleResponse(response);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  static Future<Map<String, dynamic>> put(
      String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put(endpoint, data: data);
      return _handleResponse(response);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  static Future<Map<String, dynamic>> uploadFile(
      String endpoint, dynamic fileData, String fileName,
      {String fieldName = 'file', Map<String, dynamic>? additionalData}) async {
    try {
      MultipartFile multipartFile;
      
      if (fileData is Uint8List) {
        multipartFile = MultipartFile.fromBytes(fileData, filename: fileName);
      } else if (!kIsWeb && fileData is File) {
        multipartFile = await MultipartFile.fromFile(fileData.path, filename: fileName);
      } else {
        // Fallback for when we might receive something else or if on web with unexpected types
        throw Exception('Unsupported or invalid file data for current platform');
      }

      final formData = FormData.fromMap({
        fieldName: multipartFile,
        if (additionalData != null) ...additionalData,
      });

      final response = await _dio.post(
        endpoint,
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );
      return _handleResponse(response);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      throw Exception('Upload error: $e');
    }
  }

  static Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final response = await _dio.delete(endpoint);
      return _handleResponse(response);
    } on DioException catch (e) {
      return _handleDioError(e);
    } catch (e) {
      throw Exception('Unexpected error: $e');
    }
  }

  static Future<Stream<List<int>>> getStream(String endpoint) async {
    try {
      final response = await _dio.get<ResponseBody>(
        endpoint,
        options: Options(responseType: ResponseType.stream),
      );
      
      if (response.data == null) {
        throw Exception('No data received from stream');
      }
      
      return response.data!.stream;
    } on DioException catch (e) {
      throw Exception(_handleDioError(e));
    } catch (e) {
      throw Exception('Streaming error: $e');
    }
  }

  static Map<String, dynamic> _handleResponse(Response response) {
    if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
      if (response.data == null || response.data.toString().isEmpty) {
        return {'success': true};
      }
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      return {'data': response.data};
    }
    // We should rarely hit this if we set Dio up to throw on non-2xx statuses (which is default).
    throw Exception('Request failed with status ${response.statusCode}');
  }

  static Map<String, dynamic> _handleDioError(DioException error) {
    // For 400, 401, 404, we return the error response map so services can handle validation gracefully
    if (error.response?.statusCode == 400 || 
        error.response?.statusCode == 401 || 
        error.response?.statusCode == 404) {
      
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        return data; // Return backend formatted error message
      }
      
      String errorMessage = 'Request failed with status ${error.response?.statusCode}';
      if (error.response?.statusCode == 401) {
        errorMessage = 'Unauthorized: Please log in again';
      } else if (error.response?.statusCode == 404) {
        errorMessage = 'Resource not found';
      }
      return {'error': errorMessage};
    } 
    
    // For 500 or timeout errors, throw an exception
    String message = 'Network request failed';
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      message = 'Connection timed out';
    } else if (error.type == DioExceptionType.connectionError) {
      message = 'No internet connection';
    } else if (error.response?.data is Map) {
      final data = error.response?.data as Map;
      if (data.containsKey('error')) {
        final errorObj = data['error'];
        if (errorObj is Map) {
          message = errorObj['message'] ?? message;
        } else if (errorObj is String) {
          message = errorObj;
        }
      }
    }
    throw Exception(message);
  }
}

