import 'package:dio/dio.dart';
import 'package:hifazat_app/api/client.dart';
import 'package:hifazat_app/api/models/auth.dart';
// import 'package:hifazat_app/api/models/user.dart';

class AuthService {
  final Dio _dio = ApiClient.instance.dio;

  Future<AuthResponse> login(LoginRequest request) async {
    try {
      final response = await _dio.post('/auth/login/', data: request.toJson());
      return AuthResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw e;
    }
  }

  // FIX: This method now returns void. It does not try to parse the response.
  // It only cares if the request was successful (status 201).
  Future<void> register(RegisterRequest request) async {
    try {
      await _dio.post('/auth/register/', data: request.toJson());
    } on DioException catch (e) {
      throw e;
    }
  }

  // --- Forgot password: email -> 6-digit code -> new password ---

  // Asks the backend to email a 6-digit reset code. Returns the server's message.
  Future<String> requestPasswordReset(String email) async {
    final response = await _dio.post('/auth/password-reset/', data: {'email': email});
    return response.data['detail'] as String;
  }

  // Throws a DioException (400) if the code is wrong or expired.
  Future<void> verifyPasswordResetCode(String email, String code) async {
    await _dio.post('/auth/password-reset/verify/', data: {'email': email, 'code': code});
  }

  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
    required String newPassword2,
  }) async {
    await _dio.post('/auth/password-reset/confirm/', data: {
      'email': email,
      'code': code,
      'new_password': newPassword,
      'new_password2': newPassword2,
    });
  }

  // Turns a DRF error response ({"detail": ...} or {"field": ["msg", ...]}) into one readable message.
  static String errorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        if (data['detail'] != null) return data['detail'].toString();
        for (final value in data.values) {
          if (value is List && value.isNotEmpty) return value.first.toString();
          if (value is String) return value;
        }
      }
      if (error.response == null) return 'Could not reach the server. Check your connection.';
    }
    return 'Something went wrong. Please try again.';
  }

  // NOTE: This method will not be called in the workaround, but we leave it here.
  Future<TokenRefreshResponse> refreshToken(TokenRefreshRequest request) async {
    try {
      final response = await _dio.post('/auth/refresh/', data: request.toJson());
      return TokenRefreshResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw e;
    }
  }
}