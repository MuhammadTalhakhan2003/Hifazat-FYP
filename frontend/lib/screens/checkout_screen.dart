import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:hifazat_app/providers/incident_provider.dart';
import 'package:hifazat_app/routes.dart';
import 'package:hifazat_app/widgets/incident_marker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<IncidentProvider>(context, listen: false).fetchMapIncidents();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HifazatApp'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            },
            child: const Text('Login', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: Consumer<IncidentProvider>(
        builder: (context, incidentProvider, child) {
          return FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(30.3753, 69.3451),
              initialZoom: 5.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
              ),
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
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.incidentDetail,
                          arguments: incident.id,
                        );
                      },
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushReplacementNamed(context, AppRoutes.login);
        },
        label: const Text('Login to Report'),
        icon: const Icon(Icons.login),
      ),
    );
  }
}