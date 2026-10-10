import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Carte OpenStreetMap (gratuite, sans clé) réutilisée dans le module :
/// carte des adresses, choix d'une position, carte des livreurs.
class OsmMap extends StatelessWidget {
  final LatLng center;
  final double zoom;
  final List<Marker> markers;
  final MapController? controller;
  final void Function(LatLng point)? onTap;

  /// Centre par défaut : Tunis.
  static const tunis = LatLng(36.8065, 10.1815);

  const OsmMap({
    super.key,
    this.center = tunis,
    this.zoom = 13,
    this.markers = const [],
    this.controller,
    this.onTap,
  });

  /// Épingle standard.
  static Marker pin(LatLng p,
          {Color color = Colors.red, IconData icon = Icons.location_on, VoidCallback? onTap}) =>
      Marker(
        point: p,
        width: 44,
        height: 44,
        alignment: Alignment.topCenter,
        child: GestureDetector(
          onTap: onTap,
          child: Icon(icon, color: color, size: 44),
        ),
      );

  @override
  Widget build(BuildContext context) => FlutterMap(
        mapController: controller,
        options: MapOptions(
          initialCenter: center,
          initialZoom: zoom,
          onTap: onTap == null ? null : (_, p) => onTap!(p),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.restaurant_app',
          ),
          MarkerLayer(markers: markers),
          const RichAttributionWidget(attributions: [
            TextSourceAttribution('© contributeurs OpenStreetMap'),
          ]),
        ],
      );
}
