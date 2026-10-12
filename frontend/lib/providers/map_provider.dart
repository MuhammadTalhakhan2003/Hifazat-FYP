import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:hifazat_app/api/models/hotspot.dart';
import 'package:hifazat_app/api/services/incident_service.dart';
import 'package:latlong2/latlong.dart';

class MapProvider with ChangeNotifier {
  final IncidentService _incidentService = IncidentService();

  static const int _maxCacheEntries = 30;

  bool _isHeatmapVisible = false;
  bool get isHeatmapVisible => _isHeatmapVisible;

  // Cache keyed by the rounded bbox string, so panning back to a view is instant.
  final Map<String, List<WeightedLatLng>> _heatmapCache = {};

  List<WeightedLatLng> _heatmapData = [];
  List<WeightedLatLng> get heatmapData => _heatmapData;

  // Bumped whenever heatmapData changes. The heatmap layer caches its rendered
  // tiles, so the map uses this as a key to rebuild the layer with the new data.
  int _heatmapVersion = 0;
  int get heatmapVersion => _heatmapVersion;

  bool _isHeatmapLoading = false;
  bool get isHeatmapLoading => _isHeatmapLoading;

  String? _heatmapError;
  String? get heatmapError => _heatmapError;

  // True once a fetch for the current view finished and found no hotspots.
  bool _heatmapEmpty = false;
  bool get heatmapEmpty => _heatmapEmpty;

  // Each fetch gets an id; only the latest one may update the map, so a slow
  // response for an old view can't overwrite the current one.
  int _latestRequestId = 0;

  void toggleHeatmapVisibility() {
    _isHeatmapVisible = !_isHeatmapVisible;
    if (!_isHeatmapVisible) {
      _latestRequestId++; // Ignore any fetch still in flight
      _isHeatmapLoading = false;
      _heatmapError = null;
      _heatmapEmpty = false;
      _setHeatmapData([]);
    }
    notifyListeners();
  }

  void _setHeatmapData(List<WeightedLatLng> data) {
    _heatmapData = data;
    _heatmapVersion++;
  }

  Future<void> fetchHotspots(LatLngBounds bounds) async {
    if (!_isHeatmapVisible) return;

    // Rounded so near-identical views share a cache entry.
    final bboxKey =
        '${bounds.southWest.longitude.toStringAsFixed(2)},${bounds.southWest.latitude.toStringAsFixed(2)},${bounds.northEast.longitude.toStringAsFixed(2)},${bounds.northEast.latitude.toStringAsFixed(2)}';

    final requestId = ++_latestRequestId;
    _heatmapError = null;

    final cached = _heatmapCache[bboxKey];
    if (cached != null) {
      _isHeatmapLoading = false;
      _heatmapEmpty = cached.isEmpty;
      _setHeatmapData(cached);
      notifyListeners();
      return;
    }

    // Keep showing the previous heatmap while the new one loads.
    _isHeatmapLoading = true;
    notifyListeners();

    try {
      final bboxForApi =
          '${bounds.southWest.longitude},${bounds.southWest.latitude},${bounds.northEast.longitude},${bounds.northEast.latitude}';
      final response = await _incidentService.getHotspots(queryParams: {'bbox': bboxForApi});
      if (requestId != _latestRequestId) return;

      final featuresJson = (response is Map ? response['features'] : null) as List<dynamic>? ?? [];
      final newHeatmapData = featuresJson.map((json) {
        final feature = HotspotFeature.fromJson(json as Map<String, dynamic>);
        return WeightedLatLng(
          LatLng(feature.geometry.coordinates[1], feature.geometry.coordinates[0]),
          feature.properties.density,
        );
      }).toList();

      if (_heatmapCache.length >= _maxCacheEntries) {
        _heatmapCache.remove(_heatmapCache.keys.first);
      }
      _heatmapCache[bboxKey] = newHeatmapData;
      _heatmapEmpty = newHeatmapData.isEmpty;
      _setHeatmapData(newHeatmapData);
    } catch (e) {
      if (requestId != _latestRequestId) return;
      debugPrint("Failed to fetch hotspots: $e");
      _heatmapError = "Couldn't load hotspots. Check your connection.";
    } finally {
      if (requestId == _latestRequestId) {
        _isHeatmapLoading = false;
        notifyListeners();
      }
    }
  }
}
