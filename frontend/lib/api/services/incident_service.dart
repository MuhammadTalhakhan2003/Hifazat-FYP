import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hifazat_app/api/client.dart';
import 'package:hifazat_app/api/models/incident.dart';
import 'package:hifazat_app/api/models/incident_stats.dart';
import 'package:hifazat_app/api/models/vote_response.dart';
import 'package:hifazat_app/api/models/paginated_result.dart';

class IncidentService {
  final Dio _dio = ApiClient.instance.dio;

  Future<PaginatedResult<Incident>> getIncidentsPaginated({Map<String, dynamic>? queryParams}) async {
    try {
      final response = await _dio.get('/incidents/', queryParameters: queryParams);
      
      final featureCollection = response.data['results'] as Map<String, dynamic>;
      final List<dynamic> featuresList = featureCollection['features'];
      final incidents = featuresList.map((json) => Incident.fromJson(json)).toList();

      final bool hasNext = response.data['next'] != null;

      return PaginatedResult(results: incidents, hasNext: hasNext);

    } on DioException catch (e) {
      debugPrint("DioException in getIncidentsPaginated: ${e.message}");
      throw e;
    } catch (e) {
      debugPrint("Error parsing paginated incidents: $e");
      throw Exception("Failed to parse paginated incidents from server.");
    }
  }

  Future<List<Incident>> getAllIncidentsWithPagination({Map<String, dynamic>? queryParams}) async {
    List<Incident> allIncidents = [];
    String? nextPageUrl = '/incidents/'; 

    while (nextPageUrl != null) {
      try {
        final response = await _dio.get(
          nextPageUrl,
          queryParameters: nextPageUrl == '/incidents/' ? queryParams : null,
        );
        
        final featureCollection = response.data['results'] as Map<String, dynamic>;
        final List<dynamic> featuresList = featureCollection['features'];
        
        allIncidents.addAll(featuresList.map((json) => Incident.fromJson(json)).toList());
        
        nextPageUrl = response.data['next'];
      } catch(e) {
        debugPrint("Error during pagination: $e");
        nextPageUrl = null;
      }
    }
    return allIncidents;
  }

    // FIX: Add the missing getHotspots method
  Future<dynamic> getHotspots({required Map<String, dynamic> queryParams}) async {
    try {
      final response = await _dio.get('/predict/hotspots/', queryParameters: queryParams);
      // The response is a GeoJSON FeatureCollection, return it directly
      return response.data;
    } on DioException catch (e) {
      debugPrint("DioException fetching hotspots: ${e.message}");
      throw e;
    }
  }
  
  Future<IncidentStats> getStats(StatsPeriod period) async {
    final response = await _dio.get('/incidents/stats/', queryParameters: {'period': period.apiValue});
    return IncidentStats.fromJson(period, response.data as Map<String, dynamic>);
  }

  Future<Incident> getIncidentById(int id) async {
    try {
      final response = await _dio.get('/incidents/$id/');
      return Incident.fromJson(response.data);
    } on DioException catch (e) {
      throw e;
    }
  }
  
  // FIX: This method now uses the correct model for parsing the response
  Future<Incident> createIncident(IncidentCreateRequest request) async {
    try {
      final response = await _dio.post('/incidents/', data: request.toJson());

      // 1. Parse the flat response from the server using our dedicated model.
      final createResponse = IncidentCreateResponse.fromJson(response.data);
      
      // 2. Convert the parsed response into the standard Incident object.
      return createResponse.toStandardIncident();

    } on DioException catch (e) {
      throw e;
    } catch (e) {
      // Catch any other parsing errors
      debugPrint("Error parsing createIncident response: $e");
      throw Exception("Failed to parse server response after creating incident.");
    }
  }

  Future<VoteResponse> upvoteIncident(int id) async {
    try {
      final response = await _dio.post('/incidents/$id/upvote/');
      return VoteResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw e;
    }
  }

  Future<VoteResponse> downvoteIncident(int id) async {
    try {
      final response = await _dio.post('/incidents/$id/downvote/');
      return VoteResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw e;
    }
  }
}