// Service for category API calls
import 'package:dio/dio.dart';
import 'package:hifazat_app/api/client.dart';
import 'package:hifazat_app/api/models/category.dart';

class CategoryService {
  final Dio _dio = ApiClient.instance.dio;

  Future<List<Category>> getCategories({String? search}) async {
    try {
      final response = await _dio.get('/categories/', queryParameters: {'search': search});
      // Assuming paginated response
      final List<dynamic> results = response.data['results'];
      return results.map((json) => Category.fromJson(json)).toList();
    } on DioException catch (e) {
      throw e;
    }
  }
}