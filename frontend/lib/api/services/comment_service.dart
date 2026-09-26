// Service for comment API calls
import 'package:dio/dio.dart';
import 'package:hifazat_app/api/client.dart';
import 'package:hifazat_app/api/models/comment.dart';

class CommentService {
  final Dio _dio = ApiClient.instance.dio;

  Future<List<Comment>> getCommentsForIncident(int incidentId) async {
    try {
      final response = await _dio.get('/incidents/$incidentId/comments/');
      // Assuming paginated response
      final List<dynamic> results = response.data['results'];
      return results.map((json) => Comment.fromJson(json)).toList();
    } on DioException catch (e) {
      throw e;
    }
  }

  Future<Comment> createComment(int incidentId, CommentCreateRequest request) async {
    try {
      final response = await _dio.post('/incidents/$incidentId/comments/', data: request.toJson());
      return Comment.fromJson(response.data);
    } on DioException catch (e) {
      throw e;
    }
  }

    // NEW METHOD
  Future<void> deleteComment(int commentId) async {
    try {
      // Send a DELETE request to the /api/comments/{id}/ endpoint
      await _dio.delete('/comments/$commentId/');
    } on DioException catch (e) {
      throw e;
    }
  }
}
