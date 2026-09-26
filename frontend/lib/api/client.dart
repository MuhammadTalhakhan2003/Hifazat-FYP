import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hifazat_app/auth/auth_repository.dart';
import 'package:hifazat_app/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  // Singleton pattern
  ApiClient._privateConstructor();
  static final ApiClient _instance = ApiClient._privateConstructor();
  static ApiClient get instance => _instance;

  late final Dio _dio;
  Dio get dio => _dio;

  // Used to prevent multiple token refresh requests
  bool _isRefreshing = false;

  Future<void> initialize() async {
    final baseOptions = BaseOptions(
      baseUrl: Constants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 60), // Increased timeout
      receiveTimeout: const Duration(seconds: 60), // Increased timeout
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    _dio = Dio(baseOptions);

    // Add logging interceptor only in debug mode for clean production logs
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        request: true,
        requestHeader: true,
        requestBody: true,
        responseHeader: true,
        responseBody: true,
        error: true,
        logPrint: (object) {
          debugPrint(object.toString());
        },
      ));
    }

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Attach token to headers if it exists
          final prefs = await SharedPreferences.getInstance();
          final accessToken = prefs.getString('accessToken');
          if (accessToken != null) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          debugPrint('[API Client] Error on ${e.requestOptions.path}: ${e.message}');
          if (e.response?.statusCode == 401) {
            // Prevent multiple refresh calls
            if (_isRefreshing) {
              return handler.next(e);
            }
            _isRefreshing = true;
            debugPrint('[API Client] Received 401. Attempting to refresh token...');

            // Avoid refresh loop on login or refresh endpoints
            final requestPath = e.requestOptions.path;
            if (requestPath.contains('/auth/login/') || requestPath.contains('/auth/refresh/')) {
               _isRefreshing = false;
               debugPrint('[API Client] 401 on login/refresh path. Not refreshing token.');
               return handler.next(e);
            }

            try {
              final authRepo = AuthRepository();
              final newAccessToken = await authRepo.refreshToken();

              if (newAccessToken != null) {
                debugPrint('[API Client] Token refreshed successfully. Retrying original request.');
                e.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';

                final response = await _dio.fetch(e.requestOptions);
                _isRefreshing = false;
                return handler.resolve(response);
              } else {
                debugPrint('[API Client] Token refresh failed. Logging out.');
                await AuthRepository().logout();
                _isRefreshing = false;
                return handler.next(e);
              }
            } catch (refreshError) {
              debugPrint('[API Client] Exception during token refresh. Logging out. Error: $refreshError');
              await AuthRepository().logout();
              _isRefreshing = false;
              return handler.next(e);
            }
          }
          return handler.next(e);
        },
      ),
    );
  }
}