import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/admin_service.dart';
import '../../widgets/common_widgets.dart';

/// Email groupé (EmailJS) : promotion, fermeture exceptionnelle, rappel…
class BulkEmailScreen extends StatefulWidget {
  const BulkEmailScreen({super.key});
  @override
  State<BulkEmailScreen> createState() => _BulkEmailScreenState();
}

class _BulkEmailScreenState extends State<BulkEmailScreen> {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  UserRole? _role = UserRole.client; // null = tout le monde
  bool _sending = false;
  int _done = 0;
  int _total = 0;

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    final audience = _role?.label ?? 'tous les utilisateurs';
    if (!await confirmDialog(context, 'Envoyer l\'email',
        'Envoyer « ${_subject.text} » à $audience (comptes actifs) ?',
        confirm: 'Envoyer')) {
      return;
    }
    if (!mounted) return;
    final adminId = context.read<AuthProvider>().currentUser!.id!;
    setState(() {
      _sending = true;
      _done = 0;
      _total = 0;
    });
    ({int sent, int failed})? result;
    await runWithFeedback(context, () async {
      result = await AdminService().sendBulkEmail(
        adminId: adminId,
        role: _role,
        subject: _subject.text.trim(),
        message: _message.text.trim(),
        onProgress: (d, t) {
          if (mounted) {
            setState(() {
              _done = d;
              _total = t;
            });
          }
        },
      );
    });
    if (!mounted) return;
    setState(() => _sending = false);
    final r = result;
    if (r != null) {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.mark_email_read, color: Colors.green, size: 36),
          title: const Text('Envoi terminé'),
          content: Text('${r.sent} email(s) envoyé(s)'
              '${r.failed > 0 ? ', ${r.failed} échec(s)' : ''}.'),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(c), child: const Text('OK')),
          ],
        ),
      );
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Email groupé')),
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Text('Destinataires', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final r in [UserRole.client, UserRole.livreur, UserRole.manager, null])
                ChoiceChip(
                  label: Text(r == null ? 'Tout le monde' : '${r.label}s'),
                  selected: _role == r,
                  onSelected: _sending ? null : (_) => setState(() => _role = r),
                ),
            ]),
            const SizedBox(height: 18),
            TextFormField(
              controller: _subject,
              enabled: !_sending,
              validator: Validators.required,
              decoration: const InputDecoration(
                  labelText: 'Objet', hintText: 'Ex. -20 % ce week-end !'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _message,
              enabled: !_sending,
              validator: Validators.required,
              minLines: 5,
              maxLines: 10,
              decoration: const InputDecoration(
                  labelText: 'Message', alignLabelWithHint: true),
            ),
            const SizedBox(height: 10),
            const Text(
                'Envoi via EmailJS (modèle « statut »), un email par seconde. '
                'Le plan gratuit permet 200 emails par mois.',
                style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            if (_sending) ...[
              LinearProgressIndicator(value: _total == 0 ? null : _done / _total),
              const SizedBox(height: 8),
              Text(_total == 0 ? 'Préparation…' : 'Envoi $_done / $_total…',
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: _sending ? null : _send,
              icon: const Icon(Icons.send),
              label: const Text('Envoyer'),
            ),
          ]),
        ),
      );
}
