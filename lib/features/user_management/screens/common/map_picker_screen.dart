import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../services/geocoding_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/osm_map.dart';

/// Choix d'une position en touchant la carte. Retourne un [LatLng].
class MapPickerScreen extends StatefulWidget {
  final LatLng? initial;
  const MapPickerScreen({super.key, this.initial});
  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final _map = MapController();
  late LatLng? _point = widget.initial;
  bool _locating = false;

  Future<void> _myPosition() async {
    setState(() => _locating = true);
    await runWithFeedback(context, () async {
      final pos = await GeocodingService().currentPosition();
      final p = LatLng(pos.latitude, pos.longitude);
      setState(() => _point = p);
      _map.move(p, 16);
    });
    if (mounted) setState(() => _locating = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Choisir sur la carte')),
        body: Stack(children: [
          OsmMap(
            controller: _map,
            center: widget.initial ?? OsmMap.tunis,
            zoom: widget.initial == null ? 12 : 16,
            markers: [if (_point != null) OsmMap.pin(_point!)],
            onTap: (p) => setState(() => _point = p),
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _point == null
                      ? 'Touche la carte pour placer ton adresse.'
                      : 'Position choisie. Touche ailleurs pour la déplacer.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ]),
        floatingActionButton: Column(mainAxisSize: MainAxisSize.min, children: [
          FloatingActionButton.small(
            heroTag: 'me',
            onPressed: _locating ? null : _myPosition,
            child: _locating
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'ok',
            onPressed: _point == null ? null : () => Navigator.pop(context, _point),
            icon: const Icon(Icons.check),
            label: const Text('Valider'),
          ),
        ]),
      );
}
