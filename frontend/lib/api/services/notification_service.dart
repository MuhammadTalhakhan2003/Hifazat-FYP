// Service for notification API calls
import 'package:dio/dio.dart';
import 'package:hifazat_app/api/client.dart';
import 'package:hifazat_app/api/models/notification.dart';

class NotificationService {
  final Dio _dio = ApiClient.instance.dio;

  // Placeholder - Assuming an endpoint like /notifications/
  Future<List<NotificationModel>> getNotifications() async {
    try {
      final response = await _dio.get('/notifications/');
      final List<dynamic> results = response.data['results'];
      return results.map((json) => NotificationModel.fromJson(json)).toList();
    } on DioException catch (e) {
      // Return empty list on error for now
      print('Failed to get notifications: $e');
      return [];
    }
  }
}