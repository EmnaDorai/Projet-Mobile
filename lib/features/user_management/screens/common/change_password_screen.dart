import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/password_hasher.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/password_strength.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final id = context.read<AuthProvider>().currentUser!.id!;
    final ok = await runWithFeedback(
        context, () => AuthService().changePassword(id, _old.text, _new.text),
        success: 'Mot de passe modifié');
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _old.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mot de passe')),
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            PasswordField(controller: _old, label: 'Mot de passe actuel'),
            const SizedBox(height: 14),
            PasswordField(
                controller: _new,
                label: 'Nouveau mot de passe',
                validator: PasswordHasher.validate),
            PasswordStrengthMeter(controller: _new),
            const SizedBox(height: 14),
            PasswordField(
                controller: _confirm,
                label: 'Confirmer',
                validator: (v) => v != _new.text ? 'Ne correspond pas' : null),
            const SizedBox(height: 8),
            const Text('8 caractères min., une majuscule et un chiffre.',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Modifier')),
          ]),
        ),
      );
}
