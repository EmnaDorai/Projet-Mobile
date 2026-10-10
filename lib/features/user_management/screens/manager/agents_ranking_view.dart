import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../dao/delivery_agent_dao.dart';
import '../../dao/history_repository.dart';
import '../../models/user.dart';
import '../../widgets/common_widgets.dart';

/// Classement des livreurs : livraisons du mois en cours
/// (lu dans les tables du module Livraison).
class AgentsRankingView extends StatelessWidget {
  final void Function(User user) onOpen;
  const AgentsRankingView({super.key, required this.onOpen});

  Future<List<(User, int)>> _load() async {
    final agents = await DeliveryAgentDao().getAllWithProfile();
    final now = DateTime.now();
    final history = HistoryRepository();
    final rows = <(User, int)>[];
    for (final (u, _) in agents) {
      rows.add((u, await history.countAgentDeliveriesSince(u.id!, DateTime(now.year, now.month))));
    }
    rows.sort((a, b) => b.$2.compareTo(a.$2));
    return rows;
  }

  static const _medals = [Color(0xFFF2A93B), Color(0xFF9EA7AE), Color(0xFFB8733D)];

  @override
  Widget build(BuildContext context) => FutureBuilder<List<(User, int)>>(
        future: _load(),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final rows = snap.data!;
          if (rows.isEmpty) {
            return const EmptyState(icon: Icons.emoji_events_outlined, message: 'Aucun livreur');
          }
          final best = rows.first.$2;
          return ListView(padding: const EdgeInsets.all(12), children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 4, 4, 12),
              child: Text('Livraisons effectuées ce mois-ci',
                  style: TextStyle(color: AppColors.muted)),
            ),
            for (var i = 0; i < rows.length; i++)
              Card(
                child: ListTile(
                  onTap: () => onOpen(rows[i].$1),
                  leading: CircleAvatar(
                    backgroundColor: i < 3 ? _medals[i] : AppColors.field,
                    foregroundColor: i < 3 ? Colors.white : AppColors.olive,
                    child: i < 3
                        ? const Icon(Icons.emoji_events, size: 20)
                        : Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  title: Text(rows[i].$1.nomComplet),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: best == 0 ? 0 : rows[i].$2 / best,
                        minHeight: 6,
                        color: AppColors.oliveSoft,
                        backgroundColor: AppColors.line,
                      ),
                    ),
                  ),
                  trailing: Text('${rows[i].$2}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
              ),
          ]);
        },
      );
}
