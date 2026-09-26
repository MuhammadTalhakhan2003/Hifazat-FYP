import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:hifazat_app/api/models/hotspot.dart';
import 'package:hifazat_app/api/services/incident_service.dart';
import 'package:latlong2/latlong.dart';

class MapProvider with ChangeNotifier {
  final IncidentService _incidentService = IncidentService();

  bool _isHeatmapVisible = false;
  bool get isHeatmapVisible => _isHeatmapVisible;

  // FIX: Implement a simple cache. The key will be the bbox string.
  final Map<String, List<WeightedLatLng>> _heatmapCache = {};

  List<WeightedLatLng> _heatmapData = [];
  List<WeightedLatLng> get heatmapData => _heatmapData;

  bool _isHeatmapLoading = false;
  bool get isHeatmapLoading => _isHeatmapLoading;
  
  void toggleHeatmapVisibility() {
    _isHeatmapVisible = !_isHeatmapVisible;
    if (!_isHeatmapVisible) {
      _heatmapData = [];
    }
    notifyListeners();
  }

  Future<void> fetchHotspots(LatLngBounds bounds) async {
    if (!_isHeatmapVisible) {
      if (_heatmapData.isNotEmpty) {
        _heatmapData = [];
        notifyListeners();
      }
      return;
    }
    
    // Create a key for the cache from the bounding box.
    // We round the coordinates to make the cache more effective for similar-but-not-identical views.
    final bboxKey =
        '${bounds.southWest.longitude.toStringAsFixed(2)},${bounds.southWest.latitude.toStringAsFixed(2)},${bounds.northEast.longitude.toStringAsFixed(2)},${bounds.northEast.latitude.toStringAsFixed(2)}';
    
    // FIX: Check the cache first!
    if (_heatmapCache.containsKey(bboxKey)) {
      debugPrint("Found hotspot data in cache for key: $bboxKey");
      _heatmapData = _heatmapCache[bboxKey]!;
      notifyListeners();
      return; // Exit without making an API call
    }
    
    debugPrint("Fetching new hotspot data for key: $bboxKey");
    _isHeatmapLoading = true;
    notifyListeners();

    try {
      final bboxForApi =
          '${bounds.southWest.longitude},${bounds.southWest.latitude},${bounds.northEast.longitude},${bounds.northEast.latitude}';
      
      final response = await _incidentService.getHotspots(queryParams: {'bbox': bboxForApi});
      
      final List<dynamic> featuresJson = response['features'] as List<dynamic>;
      final features = featuresJson.map((json) => HotspotFeature.fromJson(json)).toList();
      
      final newHeatmapData = features.map((feature) {
        return WeightedLatLng(
          LatLng(
            feature.geometry.coordinates[1],
            feature.geometry.coordinates[0],
          ),
          feature.properties.density,
        );
      }).toList();

      // Update the main data and store it in the cache
      _heatmapData = newHeatmapData;
      _heatmapCache[bboxKey] = newHeatmapData;

    } catch (e) {
      debugPrint("Failed to fetch hotspots: $e");
      _heatmapData = [];
    } finally {
      _isHeatmapLoading = false;
      notifyListeners();
    }
  }
}