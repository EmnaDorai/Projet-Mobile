import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/biometric_service.dart';
import '../../services/export_service.dart';
import '../../services/otp_service.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/export_sheet.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';
import 'login_history_screen.dart';
import 'security_question_screen.dart';

/// Espace « Mon profil » commun aux 4 rôles. Chaque espace peut ajouter ses
/// propres entrées via [extraTiles] (adresses, préférences, véhicule…).
class ProfileScreen extends StatelessWidget {
  final List<Widget> extraTiles;
  const ProfileScreen({super.key, this.extraTiles = const []});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser!;
    void open(Widget w) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => w));

    return ListView(children: [
      const SizedBox(height: 24),
      Center(child: UserAvatar(user: user, radius: 48)),
      const SizedBox(height: 12),
      Center(
          child: Text(user.nomComplet,
              style: Theme.of(context).textTheme.titleLarge)),
      Center(child: Text(user.email)),
      const SizedBox(height: 8),
      Center(child: RoleChip(user.role)),
      const SizedBox(height: 16),
      _section('Mon compte'),
      ListTile(
        leading: const Icon(Icons.person_outline),
        title: const Text('Modifier mes informations'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => open(const EditProfileScreen()),
      ),
      ListTile(
        leading: const Icon(Icons.lock_outline),
        title: const Text('Changer le mot de passe'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => open(const ChangePasswordScreen()),
      ),
      ListTile(
        leading: const Icon(Icons.shield_outlined),
        title: const Text('Question de sécurité'),
        subtitle: Text(user.questionSecurite?.isNotEmpty == true
            ? user.questionSecurite!
            : 'Non définie'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => open(const SecurityQuestionScreen()),
      ),
      _BiometricTile(userId: user.id!),
      _TwoFactorTile(userId: user.id!, email: user.email),
      ListTile(
        leading: const Icon(Icons.devices_other),
        title: const Text('Historique des connexions'),
        subtitle: const Text('Date, méthode et appareil'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => open(LoginHistoryScreen(userId: user.id!)),
      ),
      if (extraTiles.isNotEmpty) ...[_section('Mon espace'), ...extraTiles],
      _section('Mes données'),
      ListTile(
        leading: const Icon(Icons.picture_as_pdf_outlined),
        title: const Text('Exporter mes données'),
        subtitle: const Text('Profil, adresses et historique en PDF'),
        trailing: const Icon(Icons.download_outlined),
        onTap: () => exportWithChoice(context,
            title: 'Exporter mes données (PDF)',
            run: (mode) => ExportService().exportMyData(user, mode: mode)),
      ),
      const Divider(height: 32),
      ListTile(
        leading: const Icon(Icons.logout),
        title: const Text('Se déconnecter'),
        onTap: () async {
          if (await confirmDialog(context, 'Déconnexion', 'Voulez-vous vous déconnecter ?')) {
            await auth.logout();
          }
        },
      ),
      if (user.role != UserRole.admin)
        ListTile(
          leading: const Icon(Icons.delete_forever, color: Colors.red),
          title: const Text('Supprimer mon compte',
              style: TextStyle(color: Colors.red)),
          subtitle: const Text('Définitif : profil, adresses et préférences'),
          onTap: () => _deleteAccount(context, auth, user),
        ),
      const SizedBox(height: 24),
    ]);
  }

  /// Suppression par l'utilisateur, confirmée par son mot de passe.
  Future<void> _deleteAccount(BuildContext context, AuthProvider auth, User user) async {
    final ctrl = TextEditingController();
    final pwd = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.warning_amber, color: Colors.red, size: 36),
        title: const Text('Supprimer mon compte'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Cette action est définitive. Saisis ton mot de passe pour confirmer.'),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            obscureText: true,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Mot de passe'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, ctrl.text),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (pwd == null || !context.mounted) return;
    final ok = await runWithFeedback(
        context, () => AuthService().deleteOwnAccount(user.id!, pwd),
        success: 'Compte supprimé. À bientôt !');
    if (ok) await auth.clearAfterDeletion();
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(t.toUpperCase(),
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
      );
}

/// Active / désactive la connexion par empreinte ou visage sur ce téléphone.
class _BiometricTile extends StatefulWidget {
  final int userId;
  const _BiometricTile({required this.userId});
  @override
  State<_BiometricTile> createState() => _BiometricTileState();
}

class _BiometricTileState extends State<_BiometricTile> {
  final _bio = BiometricService();
  bool? _available;
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final available = await _bio.isAvailable();
    final enabled = await _bio.enrolledUserId() == widget.userId;
    if (mounted) {
      setState(() {
        _available = available;
        _enabled = enabled;
      });
    }
  }

  Future<void> _toggle(bool on) async {
    if (!on) {
      await _bio.disable();
      setState(() => _enabled = false);
      return;
    }
    await runWithFeedback(context, () async {
      if (await _bio.authenticate('Confirme pour activer la connexion biométrique')) {
        await _bio.enable(widget.userId);
        setState(() => _enabled = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_available == null) return const SizedBox.shrink();
    return SwitchListTile(
      secondary: const Icon(Icons.fingerprint),
      title: const Text('Connexion par empreinte ou visage'),
      subtitle: Text(_available!
          ? 'Se connecter sans mot de passe sur ce téléphone'
          : 'Aucune empreinte ni visage enregistré dans le téléphone'),
      value: _enabled,
      onChanged: _available! ? _toggle : null,
    );
  }
}

/// Double authentification : un code par email est demandé à chaque
/// connexion par mot de passe.
class _TwoFactorTile extends StatefulWidget {
  final int userId;
  final String email;
  const _TwoFactorTile({required this.userId, required this.email});
  @override
  State<_TwoFactorTile> createState() => _TwoFactorTileState();
}

class _TwoFactorTileState extends State<_TwoFactorTile> {
  final _auth = AuthService();
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    _auth.isTwoFactorEnabled(widget.userId).then((v) {
      if (mounted) setState(() => _enabled = v);
    });
  }

  Future<String?> _ask(String title, String hint, {bool password = false}) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          obscureText: password,
          keyboardType: password ? TextInputType.text : TextInputType.number,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('Valider')),
        ],
      ),
    );
  }

  Future<void> _toggle(bool on) async {
    if (on) {
      // 1. envoi d'un code, 2. saisie : prouve que l'email fonctionne.
      final sent = await runWithFeedback(context,
          () => _auth.sendOtp(widget.userId, OtpPurpose.twoFactor, resend: true));
      if (!sent || !mounted) return;
      final code = await _ask('Code envoyé à ${widget.email}', 'Code à 6 chiffres');
      if (code == null || !mounted) return;
      final ok = await runWithFeedback(
          context, () => _auth.enableTwoFactor(widget.userId, code),
          success: 'Double authentification activée');
      if (ok && mounted) setState(() => _enabled = true);
    } else {
      final pwd = await _ask('Désactiver la double authentification', 'Mot de passe',
          password: true);
      if (pwd == null || !mounted) return;
      final ok = await runWithFeedback(
          context, () => _auth.disableTwoFactor(widget.userId, pwd),
          success: 'Double authentification désactivée');
      if (ok && mounted) setState(() => _enabled = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_enabled == null) return const SizedBox.shrink();
    return SwitchListTile(
      secondary: const Icon(Icons.verified_user_outlined),
      title: const Text('Double authentification'),
      subtitle: const Text('Code par email à chaque connexion'),
      value: _enabled!,
      onChanged: _toggle,
    );
  }
}
