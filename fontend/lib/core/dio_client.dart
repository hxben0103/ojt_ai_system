import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

class DioClient {
  static final DioClient _instance = DioClient._internal();
  late final Dio _dio;
  static const String _tokenKey = 'auth_token';
  
  // Cache SharedPreferences globally to avoid instance overhead on every request
  SharedPreferences? _prefsCache;

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

          // Dynamically adjust timeouts for AI and image endpoints
          if (options.path.contains('/prediction') || options.path.contains('/ai') || options.path.contains('/chat') || options.path.contains('/image')) {
            options.receiveTimeout = ApiConfig.aiTimeout;
            options.connectTimeout = ApiConfig.aiTimeout;
          }

          _prefsCache ??= await SharedPreferences.getInstance();
          final token = _prefsCache?.getString(_tokenKey);
          
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
        onError: (DioException e, handler) async {
          if (kDebugMode) {
            print('[DIO - ERROR] ${e.response?.statusCode} ${e.requestOptions.uri}: ${e.message}');
          }
          
          // Simple retry logic for 503 Service Unavailable or Connection Timeouts
          if (e.response?.statusCode == 503 || e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
            // Attempt to read from config / interceptor metadata if we've retried
            final retries = e.requestOptions.extra['retries'] ?? 0;
            if (retries < 2) { // Max 2 retries
              if (kDebugMode) {
                print('[DIO - RETRY] Retrying ${e.requestOptions.uri} (Attempt ${retries + 1})...');
              }
              e.requestOptions.extra['retries'] = retries + 1;
              try {
                // Wait briefly before retrying
                await Future.delayed(const Duration(seconds: 1));
                final response = await _dio.request(
                  e.requestOptions.path,
                  options: Options(
                    method: e.requestOptions.method,
                    headers: e.requestOptions.headers,
                    extra: e.requestOptions.extra,
                  ),
                  data: e.requestOptions.data,
                  queryParameters: e.requestOptions.queryParameters,
                );
                return handler.resolve(response);
              } catch (retryError) {
                // Fallthrough if retry fails
              }
            }
          }
          
          return handler.next(e);
        },
      ),
    );
  }

  Dio get dio => _dio;
}

