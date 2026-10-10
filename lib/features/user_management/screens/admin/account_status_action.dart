import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/admin_service.dart';
import '../../services/auth_exception.dart';
import '../../widgets/common_widgets.dart';

/// Active ou désactive le compte [user] après confirmation, puis envoie
/// un email à l'utilisateur. Retourne true si le statut a changé.
Future<bool> toggleAccountStatus(BuildContext context, User user) async {
  final me = context.read<AuthProvider>().currentUser!.id!;
  final activate = user.estBloque;
  final confirmed = await confirmDialog(
    context,
    activate ? 'Activer le compte' : 'Désactiver le compte',
    '${activate ? '${user.nomComplet} pourra se connecter.' : '${user.nomComplet} ne pourra plus se connecter.'}'
        '\n\nUn email sera envoyé à ${user.email}.',
    confirm: activate ? 'Activer' : 'Désactiver',
    danger: !activate,
  );
  if (!confirmed || !context.mounted) return false;
  final messenger = ScaffoldMessenger.of(context);
  try {
    final mail = await AdminService().setBlocked(me, user, !activate);
    messenger.showSnackBar(SnackBar(
        content: Text('Compte ${activate ? 'activé' : 'désactivé'} — $mail')));
    return true;
  } on AuthException catch (e) {
    messenger.showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    return false;
  }
}

/// Interrupteur « Compte actif » réutilisable (liste et fiche utilisateur).
class AccountStatusSwitch extends StatelessWidget {
  final User user;
  final VoidCallback onChanged;
  const AccountStatusSwitch({super.key, required this.user, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isMe = context.read<AuthProvider>().currentUser?.id == user.id;
    return Switch(
      value: !user.estBloque,
      activeThumbColor: Colors.white,
      activeTrackColor: Colors.green,
      onChanged: isMe
          ? null
          : (_) async {
              if (await toggleAccountStatus(context, user)) onChanged();
            },
    );
  }
}
