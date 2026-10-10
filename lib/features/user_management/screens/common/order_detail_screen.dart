import 'package:flutter/material.dart';

import '../../dao/history_repository.dart';
import '../../widgets/common_widgets.dart';

/// Détail d'une commande passée (lecture seule).
/// Les noms de colonnes des lignes de commande dépendent du module Commandes :
/// adapter `_itemLabel` / `_itemQty` / `_itemPrice` si besoin.
class OrderDetailScreen extends StatelessWidget {
  final int orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  static const _itemLabel = ['nom_plat', 'nom', 'plat', 'libelle'];
  static const _itemQty = ['quantite', 'qte'];
  static const _itemPrice = ['prix_unitaire', 'prix'];

  Object? _pick(Map<String, Object?> m, List<String> keys) {
    for (final k in keys) {
      if (m[k] != null) return m[k];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Commande #$orderId')),
      body: FutureBuilder(
        future: HistoryRepository().getOrderDetail(orderId),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final order = snap.data!.order;
          final items = snap.data!.items;
          if (order == null) {
            return const EmptyState(
                icon: Icons.search_off, message: 'Commande introuvable');
          }
          final date = DateTime.tryParse('${order[HistoryConfig.orderDate]}');
          return ListView(padding: const EdgeInsets.all(16), children: [
            Card(
              child: ListTile(
                title: const Text('Statut'),
                trailing: TextStatusChip('${order[HistoryConfig.orderStatus] ?? '-'}'),
                subtitle: date == null ? null : Text(formatDate(date, withTime: true)),
              ),
            ),
            const SizedBox(height: 12),
            Text('Articles', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Text('Détail des articles indisponible.',
                  style: TextStyle(color: Colors.grey))
            else
              Card(
                child: Column(children: [
                  for (final it in items)
                    ListTile(
                      dense: true,
                      title: Text('${_pick(it, _itemLabel) ?? 'Article'}'),
                      leading: Text('x${_pick(it, _itemQty) ?? 1}'),
                      trailing: _pick(it, _itemPrice) == null
                          ? null
                          : Text(
                              '${(_pick(it, _itemPrice) as num).toStringAsFixed(2)} DT'),
                    ),
                ]),
              ),
            const SizedBox(height: 12),
            if (order[HistoryConfig.orderTotal] != null)
              Card(
                child: ListTile(
                  title: const Text('Total',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Text(
                      '${(order[HistoryConfig.orderTotal] as num).toStringAsFixed(2)} DT',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
          ]);
        },
      ),
    );
  }
}
