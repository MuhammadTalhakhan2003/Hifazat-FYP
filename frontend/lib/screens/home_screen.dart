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

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();
  final StreamController<void> _rebuildStream = StreamController.broadcast();
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
    _rebuildStream.close();
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
                      heatMapDataSource: InMemoryHeatMapDataSource(data: mapProvider.heatmapData),
                      heatMapOptions: HeatMapOptions(
                        radius: 40,
                        gradient: {
                            0.2: Colors.blue,
                            0.4: Colors.green,
                            0.6: Colors.yellow,
                            0.8: Colors.red,
                            1.0: Colors.red,
                        },
                        minOpacity: 0.3,
                      ),
                      reset: _rebuildStream.stream,
                    ),
                ],
              ),
              if (mapProvider.isHeatmapLoading)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        SizedBox(width: 8),
                        Text("Loading Hotspots...", style: TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
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
}