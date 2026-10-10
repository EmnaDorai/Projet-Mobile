import 'package:flutter/material.dart';

import '../../dao/activity_log_dao.dart';
import '../../models/activity_log.dart';
import '../../widgets/common_widgets.dart';
import '../admin/activity_logs_view.dart';

/// Connexions récentes du compte : date, méthode et appareil.
/// Permet de repérer une connexion inconnue ou des échecs suspects.
class LoginHistoryScreen extends StatelessWidget {
  final int userId;
  const LoginHistoryScreen({super.key, required this.userId});

  Future<List<ActivityLog>> _load() async {
    final all = await ActivityLogDao().getByUser(userId, limit: 300);
    return all.where((l) => LogAction.loginActions.contains(l.action)).take(50).toList();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Historique des connexions')),
        body: FutureBuilder<List<ActivityLog>>(
          future: _load(),
          builder: (_, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final logs = snap.data!;
            if (logs.isEmpty) {
              return const EmptyState(
                  icon: Icons.devices_other, message: 'Aucune connexion enregistrée');
            }
            return ListView(children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                    'Tu ne reconnais pas une connexion ? Change ton mot de passe '
                    'et active la double authentification.',
                    style: TextStyle(color: Colors.grey)),
              ),
              for (final l in logs) LogTile(log: l),
            ]);
          },
        ),
      );
}
