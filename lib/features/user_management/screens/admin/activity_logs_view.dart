import 'package:flutter/material.dart';

import '../../dao/activity_log_dao.dart';
import '../../models/activity_log.dart';
import '../../widgets/common_widgets.dart';

/// Journal d'activité global (Admin), filtrable par type d'action.
class ActivityLogsView extends StatefulWidget {
  const ActivityLogsView({super.key});
  @override
  State<ActivityLogsView> createState() => _ActivityLogsViewState();
}

class _ActivityLogsViewState extends State<ActivityLogsView> {
  String? _action;
  late Future<List<ActivityLog>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() {
        _future = ActivityLogDao().getAll(action: _action, limit: 200);
      });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: DropdownButtonFormField<String?>(
          initialValue: _action,
          isExpanded: true, // libellés longs : coupés au lieu de déborder
          decoration: const InputDecoration(
              labelText: 'Type d\'action', prefixIcon: Icon(Icons.filter_list)),
          items: [
            const DropdownMenuItem(value: null, child: Text('Toutes')),
            for (final a in LogAction.all)
              DropdownMenuItem(
                  value: a,
                  child: Text(LogTile.label(a), overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) {
            _action = v;
            _reload();
          },
        ),
      ),
      Expanded(
        child: FutureBuilder<List<ActivityLog>>(
          future: _future,
          builder: (_, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            if (snap.data!.isEmpty) {
              return const EmptyState(icon: Icons.history, message: 'Aucune activité');
            }
            return RefreshIndicator(
              onRefresh: () async => _reload(),
              child: ListView.separated(
                itemCount: snap.data!.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) => LogTile(log: snap.data![i], showUser: true),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

class LogTile extends StatelessWidget {
  final ActivityLog log;
  final bool showUser;
  const LogTile({super.key, required this.log, this.showUser = false});

  static String label(String action) => const {
        LogAction.login: 'Connexion',
        LogAction.logout: 'Déconnexion',
        LogAction.loginFailed: 'Échec de connexion',
        LogAction.register: 'Inscription',
        LogAction.updateProfile: 'Profil modifié',
        LogAction.changePassword: 'Mot de passe changé',
        LogAction.resetPassword: 'Mot de passe réinitialisé',
        LogAction.createUser: 'Compte créé',
        LogAction.changeRole: 'Rôle modifié',
        LogAction.blockUser: 'Compte désactivé',
        LogAction.unblockUser: 'Compte activé',
        LogAction.deleteUser: 'Compte supprimé',
        LogAction.availability: 'Disponibilité',
        LogAction.resetCodeSent: 'Code de réinitialisation envoyé',
        LogAction.biometricLogin: 'Connexion biométrique',
        LogAction.googleLogin: 'Connexion Google',
        LogAction.accountLocked: 'Compte verrouillé (5 échecs)',
        LogAction.emailVerified: 'Email vérifié',
        LogAction.twoFactorLogin: 'Connexion avec code (2FA)',
        LogAction.twoFactorSetting: 'Double authentification',
        LogAction.sessionExpired: 'Déconnexion automatique',
        LogAction.referral: 'Parrainage',
        LogAction.deleteOwnAccount: 'Compte supprimé par l\'utilisateur',
        LogAction.exportData: 'Export de données',
        LogAction.bulkEmail: 'Email groupé',
        LogAction.uploadDocument: 'Document envoyé',
      }[action] ??
      action;

  static IconData _icon(String a) => switch (a) {
        LogAction.login ||
        LogAction.biometricLogin ||
        LogAction.googleLogin ||
        LogAction.twoFactorLogin =>
          Icons.login,
        LogAction.accountLocked => Icons.lock_clock,
        LogAction.emailVerified => Icons.verified_outlined,
        LogAction.sessionExpired => Icons.timer_off_outlined,
        LogAction.bulkEmail => Icons.forward_to_inbox,
        LogAction.resetCodeSent => Icons.mark_email_read_outlined,
        LogAction.logout => Icons.logout,
        LogAction.loginFailed => Icons.warning_amber,
        LogAction.register || LogAction.createUser => Icons.person_add,
        LogAction.blockUser => Icons.block,
        LogAction.unblockUser => Icons.lock_open,
        LogAction.deleteUser => Icons.delete_outline,
        LogAction.changeRole => Icons.swap_horiz,
        LogAction.availability => Icons.toggle_on_outlined,
        _ => Icons.edit_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final danger = log.action == LogAction.loginFailed ||
        log.action == LogAction.accountLocked ||
        log.action == LogAction.blockUser ||
        log.action == LogAction.deleteUser;
    final sub = [
      if (showUser) log.userEmail ?? 'Utilisateur supprimé',
      if (log.details?.isNotEmpty == true) log.details!,
    ].join(' · ');
    return ListTile(
      dense: true,
      leading: Icon(_icon(log.action), color: danger ? Colors.red : null),
      title: Text(label(log.action)),
      subtitle: sub.isEmpty ? null : Text(sub),
      trailing: Text(formatDate(log.date, withTime: true),
          style: const TextStyle(fontSize: 12, color: Colors.grey)),
    );
  }
}
