// Service for user-related API calls
import 'package:dio/dio.dart';
import 'package:hifazat_app/api/client.dart';
import 'package:hifazat_app/api/models/user.dart';

class UserService {
  final Dio _dio = ApiClient.instance.dio;

  Future<User> getCurrentUser() async {
    try {
      final response = await _dio.get('/users/me/');
      return User.fromJson(response.data);
    } on DioException catch (e) {
      throw e;
    }
  }

  Future<User> updateCurrentUser(Map<String, dynamic> data) async {
    try {
      final response = await _dio.patch('/users/me/', data: data);
      return User.fromJson(response.data);
    } on DioException catch (e) {
      throw e;
    }
  }

  Future<Reputation> getUserReputation(int userId) async {
    try {
      final response = await _dio.get('/users/$userId/reputation/');
      return Reputation.fromJson(response.data);
    } on DioException catch (e) {
      throw e;
    }
  }
}