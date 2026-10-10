import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../dao/delivery_agent_dao.dart';
import '../../models/delivery_agent.dart';
import '../../models/user.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/osm_map.dart';

/// Carte des livreurs en ligne (dernière position partagée).
class AgentsMapView extends StatefulWidget {
  final void Function(User user) onOpen;
  const AgentsMapView({super.key, required this.onOpen});
  @override
  State<AgentsMapView> createState() => _AgentsMapViewState();
}

class _AgentsMapViewState extends State<AgentsMapView> {
  late Future<List<(User, DeliveryAgent)>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() {
        _future = DeliveryAgentDao().getAllWithProfile(disponible: true);
      });

  void _showAgent(User u, DeliveryAgent a) => showModalBottomSheet<void>(
        context: context,
        builder: (c) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(
                leading: UserAvatar(user: u),
                title: Text(u.nomComplet,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${a.typeVehicule ?? 'Véhicule ?'} - ${u.telephone ?? 'pas de numéro'}'),
              ),
              ListTile(
                leading: const Icon(Icons.schedule),
                title: Text(a.positionMaj == null
                    ? 'Position : date inconnue'
                    : 'Position du ${formatDate(a.positionMaj!, withTime: true)}'),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(c);
                  widget.onOpen(u);
                },
                icon: const Icon(Icons.person_search),
                label: const Text('Voir la fiche'),
              ),
            ]),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => FutureBuilder<List<(User, DeliveryAgent)>>(
        future: _future,
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final located = snap.data!.where((e) => e.$2.hasPosition).toList();
          final first = located.isEmpty ? null : located.first.$2;
          return Stack(children: [
            OsmMap(
              center: first == null
                  ? OsmMap.tunis
                  : LatLng(first.latitude!, first.longitude!),
              zoom: 12,
              markers: [
                for (final (u, a) in located)
                  OsmMap.pin(
                    LatLng(a.latitude!, a.longitude!),
                    color: Colors.green.shade700,
                    icon: Icons.delivery_dining,
                    onTap: () => _showAgent(u, a),
                  ),
              ],
            ),
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Card(
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.circle, color: Colors.green, size: 14),
                  title: Text(located.isEmpty
                      ? 'Aucun livreur en ligne avec une position'
                      : '${located.length} livreur(s) en ligne'),
                  trailing: IconButton(
                      tooltip: 'Actualiser',
                      icon: const Icon(Icons.refresh),
                      onPressed: _reload),
                ),
              ),
            ),
          ]);
        },
      );
}
