import 'package:flutter/material.dart';

import '../../dao/history_repository.dart';
import '../../models/history_item.dart';
import '../../widgets/common_widgets.dart';
import 'order_detail_screen.dart';

/// Historique des commandes d'un client, paginé et filtrable.
/// Réutilisé par : Client (son historique), Manager et Admin (fiche client).
class OrderHistoryView extends StatefulWidget {
  final int clientId;
  const OrderHistoryView({super.key, required this.clientId});

  @override
  State<OrderHistoryView> createState() => _OrderHistoryViewState();
}

class _OrderHistoryViewState extends State<OrderHistoryView> {
  final _repo = HistoryRepository();
  final _scroll = ScrollController();
  final _items = <HistoryItem>[];
  String? _statut; // null = toutes
  DateTimeRange? _range;
  int _page = 0;
  bool _loading = false;
  bool _hasMore = true;

  // ⚠️ Valeurs à aligner avec les statuts du module Commandes.
  static const _filtres = {
    null: 'Toutes',
    'EN_COURS': 'En cours',
    'LIVREE': 'Livrées',
    'ANNULEE': 'Annulées',
  };

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 200) _load();
    });
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading || (!_hasMore && !reset)) return;
    setState(() {
      _loading = true;
      if (reset) {
        _items.clear();
        _page = 0;
        _hasMore = true;
      }
    });
    final res = await _repo.getClientOrders(
      widget.clientId,
      statut: _statut,
      from: _range?.start,
      to: _range?.end.add(const Duration(days: 1)),
      page: _page,
    );
    if (!mounted) return;
    setState(() {
      _items.addAll(res);
      _page++;
      _hasMore = res.length == HistoryRepository.pageSize;
      _loading = false;
    });
  }

  Future<void> _pickRange() async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    setState(() => _range = r);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          for (final e in _filtres.entries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(e.value),
                selected: _statut == e.key,
                onSelected: (_) {
                  setState(() => _statut = e.key);
                  _load(reset: true);
                },
              ),
            ),
          ActionChip(
            avatar: const Icon(Icons.date_range, size: 18),
            label: Text(_range == null
                ? 'Période'
                : '${formatDate(_range!.start)} → ${formatDate(_range!.end)}'),
            onPressed: _pickRange,
          ),
          if (_range != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() => _range = null);
                _load(reset: true);
              },
            ),
        ]),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: () => _load(reset: true),
          child: _items.isEmpty && !_loading
              ? ListView(children: const [
                  SizedBox(height: 80),
                  EmptyState(
                      icon: Icons.receipt_long, message: 'Aucune commande pour le moment'),
                ])
              : ListView.separated(
                  controller: _scroll,
                  itemCount: _items.length + (_hasMore ? 1 : 0),
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (c, i) {
                    if (i >= _items.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final o = _items[i];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.receipt)),
                      title: Text(o.description ?? 'Commande #${o.id}'),
                      subtitle: Text(formatDate(o.date, withTime: true)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (o.montant != null)
                            Text('${o.montant!.toStringAsFixed(2)} DT',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          TextStatusChip(o.statut),
                        ],
                      ),
                      onTap: () => Navigator.push(
                          c,
                          MaterialPageRoute(
                              builder: (_) => OrderDetailScreen(orderId: o.id))),
                    );
                  },
                ),
        ),
      ),
    ]);
  }
}
