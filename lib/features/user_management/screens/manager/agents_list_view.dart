import 'package:flutter/material.dart';

import '../../dao/delivery_agent_dao.dart';
import '../../models/delivery_agent.dart';
import '../../models/user.dart';
import '../../widgets/common_widgets.dart';

/// Liste des livreurs avec leur disponibilité (Manager).
class AgentsListView extends StatefulWidget {
  final void Function(User user) onOpen;
  const AgentsListView({super.key, required this.onOpen});
  @override
  State<AgentsListView> createState() => _AgentsListViewState();
}

class _AgentsListViewState extends State<AgentsListView> {
  bool? _dispo; // null = tous
  late Future<List<(User, DeliveryAgent)>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() {
        _future = DeliveryAgentDao().getAllWithProfile(disponible: _dispo);
      });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: SegmentedButton<bool?>(
          segments: const [
            ButtonSegment(value: null, label: Text('Tous')),
            ButtonSegment(value: true, label: Text('En ligne')),
            ButtonSegment(value: false, label: Text('Hors ligne')),
          ],
          selected: {_dispo},
          onSelectionChanged: (s) {
            _dispo = s.first;
            _reload();
          },
        ),
      ),
      Expanded(
        child: FutureBuilder<List<(User, DeliveryAgent)>>(
          future: _future,
          builder: (_, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final list = snap.data!;
            if (list.isEmpty) {
              return const EmptyState(
                  icon: Icons.delivery_dining, message: 'Aucun livreur');
            }
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final (u, a) = list[i];
                  return ListTile(
                    leading: Stack(children: [
                      UserAvatar(user: u),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: a.disponible ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ]),
                    title: Text(u.nomComplet),
                    subtitle: Text(
                        '${a.typeVehicule ?? 'Véhicule non renseigné'} · ${u.telephone ?? '—'}'),
                    trailing: u.estBloque
                        ? StatusChip(u.statut)
                        : const Icon(Icons.chevron_right),
                    onTap: () => widget.onOpen(u),
                  );
                },
              ),
            );
          },
        ),
      ),
    ]);
  }
}
