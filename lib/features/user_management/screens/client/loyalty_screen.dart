import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/loyalty_service.dart';

/// Fidélité (points, niveau) et parrainage (code à partager).
class LoyaltyScreen extends StatelessWidget {
  final int userId;
  const LoyaltyScreen({super.key, required this.userId});

  static Color _color(LoyaltyLevel l) => switch (l) {
        LoyaltyLevel.bronze => const Color(0xFFB8733D),
        LoyaltyLevel.argent => const Color(0xFF8C969E),
        LoyaltyLevel.or => AppColors.saffron,
      };

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Fidélité et parrainage')),
        body: FutureBuilder<LoyaltyInfo>(
          future: LoyaltyService().get(userId),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final info = snap.data!;
            final c = _color(info.level);
            return ListView(padding: const EdgeInsets.all(16), children: [
              // ── Carte de fidélité ──
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [AppColors.olive, AppColors.olive.withValues(alpha: .85)]),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.workspace_premium, color: c, size: 32),
                    const SizedBox(width: 10),
                    Text('Niveau ${info.level.label}',
                        style: TextStyle(
                            color: c, fontSize: 20, fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 16),
                  Text('${info.total} points',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: info.progress,
                      minHeight: 10,
                      color: c,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    info.nextLevel == null
                        ? 'Niveau maximum atteint 🎉'
                        : 'Encore ${info.nextLevel!.minPoints - info.total} points '
                            'pour le niveau ${info.nextLevel!.label}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              Row(children: [
                _stat('Commandes', '${info.nbCommandes}', Icons.receipt_long),
                _stat('Points commandes', '${info.pointsCommandes}', Icons.shopping_bag_outlined),
                _stat('Points bonus', '${info.pointsBonus}', Icons.card_giftcard),
              ]),
              const SizedBox(height: 20),

              // ── Parrainage ──
              Text('Parraine tes amis', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              const Text(
                  'Ton ami saisit ton code à l\'inscription : il gagne '
                  '${AuthService.refereeBonus} points et toi ${AuthService.referrerBonus} points.',
                  style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.qr_code_2, size: 32),
                  title: Text(info.codeParrainage ?? '—',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 2)),
                  subtitle: Text('${info.filleuls} ami(s) parrainé(s)'),
                  trailing: IconButton(
                    tooltip: 'Copier',
                    icon: const Icon(Icons.copy),
                    onPressed: info.codeParrainage == null
                        ? null
                        : () {
                            Clipboard.setData(ClipboardData(text: info.codeParrainage!));
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Code copié')));
                          },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: info.codeParrainage == null
                    ? null
                    : () => SharePlus.instance.share(ShareParams(
                          text: 'Rejoins-moi sur Bnin 🍽️ ! Utilise mon code '
                              '${info.codeParrainage} à l\'inscription pour gagner '
                              '${AuthService.refereeBonus} points de fidélité.',
                        )),
                icon: const Icon(Icons.share),
                label: const Text('Partager mon code'),
              ),
              const SizedBox(height: 24),
              Text('Comment ça marche ?', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              const _Rule('1 dinar dépensé = 1 point'),
              _Rule('Argent à partir de ${LoyaltyLevel.argent.minPoints} points'),
              _Rule('Or à partir de ${LoyaltyLevel.or.minPoints} points'),
            ]);
          },
        ),
      );

  Widget _stat(String label, String value, IconData icon) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            child: Column(children: [
              Icon(icon, color: AppColors.oliveSoft),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
            ]),
          ),
        ),
      );
}

class _Rule extends StatelessWidget {
  final String text;
  const _Rule(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          const Icon(Icons.check_circle, size: 18, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ]),
      );
}
