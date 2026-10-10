import 'package:flutter/material.dart';

import '../../dao/history_repository.dart';
import '../../models/history_item.dart';
import '../../widgets/common_widgets.dart';

/// Historique des livraisons d'un livreur, filtrable par période.
/// Réutilisé par : Livreur (son historique) et Manager (fiche livreur).
class DeliveryHistoryView extends StatefulWidget {
  final int livreurId;
  const DeliveryHistoryView({super.key, required this.livreurId});

  @override
  State<DeliveryHistoryView> createState() => _DeliveryHistoryViewState();
}

class _DeliveryHistoryViewState extends State<DeliveryHistoryView> {
  final _repo = HistoryRepository();
  final _items = <HistoryItem>[];
  DateTimeRange? _range;
  int _page = 0;
  bool _loading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      if (reset) {
        _items.clear();
        _page = 0;
      }
    });
    final res = await _repo.getAgentDeliveries(widget.livreurId,
        from: _range?.start,
        to: _range?.end.add(const Duration(days: 1)),
        page: _page);
    if (!mounted) return;
    setState(() {
      _items.addAll(res);
      _page++;
      _hasMore = res.length == HistoryRepository.pageSize;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          ActionChip(
            avatar: const Icon(Icons.date_range, size: 18),
            label: Text(_range == null
                ? 'Toutes les dates'
                : '${formatDate(_range!.start)} → ${formatDate(_range!.end)}'),
            onPressed: () async {
              final r = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDateRange: _range);
              setState(() => _range = r);
              _load(reset: true);
            },
          ),
          if (_range != null)
            IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  setState(() => _range = null);
                  _load(reset: true);
                }),
        ]),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: () => _load(reset: true),
          child: _items.isEmpty && !_loading
              ? ListView(children: const [
                  SizedBox(height: 80),
                  EmptyState(
                      icon: Icons.delivery_dining,
                      message: 'Aucune livraison pour cette période'),
                ])
              : ListView.separated(
                  itemCount: _items.length + (_hasMore ? 1 : 0),
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (c, i) {
                    if (i >= _items.length) {
                      return Center(
                        child: TextButton(
                            onPressed: _load, child: const Text('Charger plus')),
                      );
                    }
                    final d = _items[i];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.delivery_dining)),
                      title: Text(d.description ?? 'Livraison #${d.id}'),
                      subtitle: Text(formatDate(d.date, withTime: true)),
                      trailing: TextStatusChip(d.statut),
                    );
                  },
                ),
        ),
      ),
    ]);
  }
}
