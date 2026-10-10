import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../models/user.dart';
import '../services/auth_exception.dart';

/// Validateurs de formulaires réutilisés dans le module.
class Validators {
  static String? required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Champ obligatoire' : null;

  static String? email(String? v) {
    if (required(v) != null) return 'Champ obligatoire';
    return RegExp(r'^[\w.+-]+@[\w-]+\.[\w.]+$').hasMatch(v!.trim())
        ? null
        : 'Email invalide';
  }

  /// Téléphone tunisien : 8 chiffres (optionnel).
  static String? phone(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return RegExp(r'^(\+216)?\s?\d{8}$').hasMatch(v.replaceAll(' ', ''))
        ? null
        : 'Numéro invalide (8 chiffres)';
  }
}

class UserAvatar extends StatelessWidget {
  final User user;
  final double radius;
  const UserAvatar({super.key, required this.user, this.radius = 22});

  /// Avatar généré par l'API gratuite UI Avatars (initiales sur fond de
  /// la couleur du rôle) quand l'utilisateur n'a pas de photo.
  String get _uiAvatarUrl {
    final hex = roleColor(user.role).toARGB32().toRadixString(16).substring(2);
    final name = Uri.encodeComponent('${user.prenom} ${user.nom}');
    return 'https://ui-avatars.com/api/?name=$name&background=$hex'
        '&color=ffffff&size=${(radius * 4).round()}&bold=true&format=png';
  }

  @override
  Widget build(BuildContext context) {
    final photo = user.photo;
    if (photo != null && File(photo).existsSync()) {
      return CircleAvatar(radius: radius, backgroundImage: FileImage(File(photo)));
    }
    final initials = Text(
      '${user.prenom.isNotEmpty ? user.prenom[0] : ''}${user.nom.isNotEmpty ? user.nom[0] : ''}'
          .toUpperCase(),
      style: TextStyle(
          color: roleColor(user.role),
          fontWeight: FontWeight.bold,
          fontSize: radius * .7),
    );
    return CircleAvatar(
      radius: radius,
      backgroundColor: roleColor(user.role).withValues(alpha: .15),
      child: ClipOval(
        child: Image.network(
          _uiAvatarUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          // Hors connexion : initiales dessinées localement.
          errorBuilder: (_, __, ___) => Center(child: initials),
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : Center(child: initials),
        ),
      ),
    );
  }
}

Color roleColor(UserRole r) => switch (r) {
      UserRole.client => const Color(0xFF2E7D6B),
      UserRole.admin => AppColors.harissa,
      UserRole.manager => AppColors.oliveSoft,
      UserRole.livreur => const Color(0xFFC77A12),
    };

class RoleChip extends StatelessWidget {
  final UserRole role;
  const RoleChip(this.role, {super.key});
  @override
  Widget build(BuildContext context) => _Pill(role.label, roleColor(role));
}

class StatusChip extends StatelessWidget {
  final UserStatus status;
  const StatusChip(this.status, {super.key});
  @override
  Widget build(BuildContext context) => _Pill(status.label,
      status == UserStatus.actif ? Colors.green : Colors.red);
}

/// Pastille pour un statut de commande/livraison venant d'un autre module.
class TextStatusChip extends StatelessWidget {
  final String text;
  const TextStatusChip(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    final t = text.toUpperCase();
    final c = t.contains('ANNUL')
        ? Colors.red
        : (t.contains('LIVR') || t.contains('TERMIN'))
            ? Colors.green
            : Colors.orange;
    return _Pill(text, c);
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill(this.text, this.color);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const EmptyState({super.key, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.saffron.withValues(alpha: .18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: AppColors.olive),
            ),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: AppColors.muted, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const StatCard(
      {super.key,
      required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 12),
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted)),
          ]),
        ),
      );
}

/// Exécute une action et affiche l'erreur (AuthException) ou un message de succès.
Future<bool> runWithFeedback(BuildContext context, Future<void> Function() action,
    {String? success}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await action();
    if (success != null) {
      messenger.showSnackBar(SnackBar(content: Text(success)));
    }
    return true;
  } on AuthException catch (e) {
    messenger.showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red));
  } catch (e) {
    messenger.showSnackBar(SnackBar(
        content: Text('Erreur inattendue : $e'), backgroundColor: Colors.red));
  }
  return false;
}

Future<bool> confirmDialog(BuildContext context, String title, String message,
    {String confirm = 'Confirmer', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: Colors.red) : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return r ?? false;
}

String formatDate(DateTime d, {bool withTime = false}) {
  String two(int n) => n.toString().padLeft(2, '0');
  final date = '${two(d.day)}/${two(d.month)}/${d.year}';
  return withTime ? '$date ${two(d.hour)}:${two(d.minute)}' : date;
}

class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  const PasswordField(
      {super.key, required this.controller, this.label = 'Mot de passe', this.validator});

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;
  @override
  Widget build(BuildContext context) => TextFormField(
        controller: widget.controller,
        obscureText: _hidden,
        validator: widget.validator ?? Validators.required,
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            icon: Icon(_hidden ? Icons.visibility : Icons.visibility_off),
            onPressed: () => setState(() => _hidden = !_hidden),
          ),
        ),
      );
}
