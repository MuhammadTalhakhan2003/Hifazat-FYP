import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:hifazat_app/providers/incident_provider.dart';
import 'package:hifazat_app/providers/map_provider.dart';
import 'package:hifazat_app/routes.dart';
import 'package:hifazat_app/widgets/incident_marker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

final Map<double, MaterialColor> _heatmapGradient = {
  0.25: Colors.blue,
  0.55: Colors.lightGreen,
  0.75: Colors.amber,
  0.9: Colors.deepOrange,
  1.0: Colors.red,
};

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<IncidentProvider>(context, listen: false).fetchMapIncidents();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final mapProvider = Provider.of<MapProvider>(context, listen: false);
      final LatLngBounds? bounds = camera.visibleBounds;
      
      if (mapProvider.isHeatmapVisible && bounds != null) {
        mapProvider.fetchHotspots(bounds);
      }
    });
  }

  void _onToggleHeatmap() {
    final mapProvider = context.read<MapProvider>();
    mapProvider.toggleHeatmapVisibility();

    if (mapProvider.isHeatmapVisible) {
      final LatLngBounds? bounds = _mapController.camera.visibleBounds;
      if (bounds != null) {
        mapProvider.fetchHotspots(bounds);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hifazat Map'),
        // This removes any icon on the top left (like a back arrow or hamburger menu)
        automaticallyImplyLeading: false,
        // FIX: The actions list is now empty, removing the filter button from the top right.
        actions: [],
      ),
      body: Consumer2<IncidentProvider, MapProvider>(
        builder: (context, incidentProvider, mapProvider, child) {
          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: const LatLng(30.3753, 69.3451),
                  initialZoom: 5.0,
                  onPositionChanged: _onPositionChanged,
                  onLongPress: (tapPosition, point) {
                    Navigator.pushNamed(context, AppRoutes.reportIncident, arguments: point);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                  ),
                  
                  if (!mapProvider.isHeatmapVisible)
                    MarkerLayer(
                      markers: incidentProvider.mapIncidents.map((incident) {
                        return Marker(
                          width: 50.0,
                          height: 70.0,
                          point: LatLng(
                            incident.geometry.coordinates[1],
                            incident.geometry.coordinates[0],
                          ),
                          child: IncidentMarker(
                            incident: incident,
                            onTap: () => Navigator.pushNamed(context, AppRoutes.incidentDetail, arguments: incident.id),
                          ),
                        );
                      }).toList(),
                    ),

                  if (mapProvider.isHeatmapVisible && mapProvider.heatmapData.isNotEmpty)
                    HeatMapLayer(
                      // The layer caches rendered tiles, so rebuild it whenever the data changes
                      key: ValueKey(mapProvider.heatmapVersion),
                      heatMapDataSource: InMemoryHeatMapDataSource(data: mapProvider.heatmapData),
                      heatMapOptions: HeatMapOptions(
                        radius: 30,
                        gradient: _heatmapGradient,
                        minOpacity: 0.15,
                      ),
                    ),
                ],
              ),
              if (mapProvider.isHeatmapVisible)
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(child: _buildHeatmapStatus(mapProvider)),
                      const SizedBox(width: 8),
                      const _HeatmapLegend(),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Consumer<MapProvider>(
            builder: (context, mapProvider, _) {
              return FloatingActionButton(
                heroTag: "heatmap_toggle_button",
                onPressed: _onToggleHeatmap,
                tooltip: 'Toggle Heatmap',
                backgroundColor: mapProvider.isHeatmapVisible ? Theme.of(context).primaryColor : Colors.white,
                foregroundColor: mapProvider.isHeatmapVisible ? Colors.white : Colors.black54,
                child: const Icon(Icons.whatshot),
              );
            },
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: "report_incident_button",
            onPressed: () => Navigator.pushNamed(context, AppRoutes.reportIncident),
            tooltip: 'Report Incident',
            child: const Icon(Icons.add_location_alt),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapStatus(MapProvider mapProvider) {
    final (IconData? icon, String text) = mapProvider.isHeatmapLoading
        ? (null, 'Analysing hotspots...')
        : mapProvider.heatmapError != null
            ? (Icons.error_outline, mapProvider.heatmapError!)
            : mapProvider.heatmapEmpty
                ? (Icons.check_circle_outline, 'No hotspots in this area')
                : (Icons.whatshot, 'Hotspots predicted from reported incidents');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon == null)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          else
            Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Flexible(
            child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _HeatmapLegend extends StatelessWidget {
  const _HeatmapLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Incident risk', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Container(
            width: 110,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: LinearGradient(colors: _heatmapGradient.values.toList()),
            ),
          ),
          const SizedBox(height: 4),
          const SizedBox(
            width: 110,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Low', style: TextStyle(fontSize: 10, color: Colors.black54)),
                Text('High', style: TextStyle(fontSize: 10, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
