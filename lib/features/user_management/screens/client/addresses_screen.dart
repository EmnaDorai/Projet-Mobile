import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../dao/address_dao.dart';
import '../../models/address.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/osm_map.dart';
import 'address_form_screen.dart';

class AddressesScreen extends StatefulWidget {
  final int userId;
  const AddressesScreen({super.key, required this.userId});
  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  final _dao = AddressDao();
  late Future<List<Address>> _future;
  bool _showMap = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() {
        _future = _dao.getByUser(widget.userId);
      });

  Future<void> _openForm([Address? a]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => AddressFormScreen(userId: widget.userId, address: a)),
    );
    if (changed == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Ajouter'),
      ),
      body: FutureBuilder<List<Address>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) {
            return const EmptyState(
                icon: Icons.location_off,
                message: 'Aucune adresse.\nAjoutez une adresse de livraison.');
          }
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Liste'), icon: Icon(Icons.list)),
                  ButtonSegment(value: true, label: Text('Carte'), icon: Icon(Icons.map_outlined)),
                ],
                selected: {_showMap},
                onSelectionChanged: (v) => setState(() => _showMap = v.first),
              ),
            ),
            Expanded(child: _showMap ? _mapView(list) : _listView(list)),
          ]);
        },
      ),
    );
  }

  /// Adresses ayant des coordonnées, affichées sur OpenStreetMap.
  Widget _mapView(List<Address> list) {
    final located = list.where((a) => a.latitude != null && a.longitude != null).toList();
    if (located.isEmpty) {
      return const EmptyState(
          icon: Icons.wrong_location_outlined,
          message: 'Aucune adresse n\'a de position.\n'
              'Modifie une adresse et choisis « Sur la carte ».');
    }
    final def = located.firstWhere((a) => a.parDefaut, orElse: () => located.first);
    return OsmMap(
      center: LatLng(def.latitude!, def.longitude!),
      zoom: 14,
      markers: [
        for (final a in located)
          OsmMap.pin(
            LatLng(a.latitude!, a.longitude!),
            color: a.parDefaut ? Colors.red : Colors.indigo,
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${a.libelle} : ${a.complete}'))),
          ),
      ],
    );
  }

  Widget _listView(List<Address> list) {
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 88),
            itemCount: list.length,
            itemBuilder: (c, i) {
              final a = list[i];
              return Card(
                child: ListTile(
                  leading: Icon(
                    a.libelle.toLowerCase().contains('travail')
                        ? Icons.work_outline
                        : Icons.home_outlined,
                    color: a.parDefaut ? Theme.of(c).colorScheme.primary : null,
                  ),
                  title: Row(children: [
                    Text(a.libelle),
                    if (a.parDefaut) ...[
                      const SizedBox(width: 8),
                      const Chip(
                          label: Text('Par défaut', style: TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact),
                    ],
                  ]),
                  subtitle: Text(a.complete),
                  onTap: () => _openForm(a),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'default') {
                        await _dao.setDefault(widget.userId, a.id!);
                      } else if (v == 'delete' &&
                          await confirmDialog(c, 'Supprimer',
                              'Supprimer l\'adresse « ${a.libelle} » ?',
                              danger: true, confirm: 'Supprimer')) {
                        await _dao.delete(widget.userId, a.id!);
                      }
                      _reload();
                    },
                    itemBuilder: (_) => [
                      if (!a.parDefaut)
                        const PopupMenuItem(
                            value: 'default', child: Text('Définir par défaut')),
                      const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
                    ],
                  ),
                ),
              );
            },
          );
  }
}
