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