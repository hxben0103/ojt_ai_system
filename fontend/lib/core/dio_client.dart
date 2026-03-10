import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

class DioClient {
  static final DioClient _instance = DioClient._internal();
  late final Dio _dio;
  static const String _tokenKey = 'auth_token';

  factory DioClient() {
    return _instance;
  }

  DioClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: ApiConfig.timeout,
        receiveTimeout: ApiConfig.timeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Always use the latest ApiConfig.baseUrl so dynamic IP changes apply immediately
          _dio.options.baseUrl = ApiConfig.baseUrl;

          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString(_tokenKey);
          
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          
          if (kDebugMode) {
            print('[DIO - REQUEST] ${options.method} ${options.uri}');
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            print('[DIO - RESPONSE] ${response.statusCode} ${response.requestOptions.uri}');
          }
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          if (kDebugMode) {
            print('[DIO - ERROR] ${e.response?.statusCode} ${e.requestOptions.uri}: ${e.message}');
          }
          return handler.next(e);
        },
      ),
    );
  }

  Dio get dio => _dio;
}
