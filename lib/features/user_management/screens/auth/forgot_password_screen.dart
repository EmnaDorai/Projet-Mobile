import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/message_senders.dart';
import '../../services/password_hasher.dart';
import '../../services/password_reset_service.dart';
import '../../widgets/auth_scaffold.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/password_strength.dart';

enum _Step { email, method, code, question }

/// Mot de passe oublié : email du compte → choix de la méthode
/// (code par email, code par SMS ou question de sécurité) → nouveau mot de passe.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _reset = PasswordResetService();
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _answer = TextEditingController();
  final _pwd = TextEditingController();

  _Step _step = _Step.email;
  ResetTarget? _target;
  ResetChannel? _channel;
  bool _busy = false;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in [_email, _code, _answer, _pwd]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    setState(() => _busy = true);
    await runWithFeedback(context, action, success: success);
    if (mounted) setState(() => _busy = false);
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = PasswordResetService.resendDelay.inSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _findAccount() async {
    if (!_form.currentState!.validate()) return;
    await _run(() async {
      final t = await _reset.findAccount(_email.text);
      setState(() {
        _target = t;
        _step = _Step.method;
      });
    });
  }

  Future<void> _sendCode(ResetChannel channel) async {
    final demoSms =
        channel == ResetChannel.sms && PasswordResetService.smsDemoMode;
    String? demoCode;
    await _run(() async {
      demoCode = await _reset.sendCode(_target!, channel);
      setState(() {
        _channel = channel;
        _step = _Step.code;
        _code.clear();
      });
      _startCooldown();
    },
        success: channel == ResetChannel.email
            ? 'Code envoyé à ${_target!.maskedEmail}'
            : demoSms
                ? null
                : 'Code envoyé par SMS au ${InfobipSmsSender.mask(_target!.phone!)}');
    if (demoCode != null && mounted) _showDemoSms(demoCode!);
  }

  /// Mode démo : simule l'arrivée du SMS sous forme de notification.
  void _showDemoSms(String code) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'SMS',
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (c, _, __) => SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Material(
              color: Colors.white,
              elevation: 8,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  _code.text = code;
                  Navigator.pop(c);
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const CircleAvatar(
                      backgroundColor: AppColors.success,
                      child: Icon(Icons.sms, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Messages · Bnin',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.olive.withValues(alpha: .8))),
                            const SizedBox(height: 4),
                            Text(
                                'Bnin : ton code de réinitialisation est $code. '
                                'Il expire dans 10 minutes.'),
                            const SizedBox(height: 8),
                            const Text(
                                'Mode démo : SMS simulé. Touche pour remplir le code.',
                                style: TextStyle(
                                    fontSize: 12, color: AppColors.muted)),
                          ]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
      transitionBuilder: (c, anim, _, child) => SlideTransition(
        position: Tween(begin: const Offset(0, -1), end: Offset.zero)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );
  }

  Future<void> _confirmCode() async {
    if (!_form.currentState!.validate()) return;
    var ok = false;
    await _run(() async {
      await _reset.resetWithCode(
          userId: _target!.userId, code: _code.text, newPassword: _pwd.text);
      ok = true;
    }, success: 'Mot de passe changé. Tu peux te connecter.');
    if (ok && mounted) Navigator.pop(context);
  }

  Future<void> _confirmQuestion() async {
    if (!_form.currentState!.validate()) return;
    var ok = false;
    await _run(() async {
      await AuthService().resetPasswordWithSecurityAnswer(
          email: _target!.email, answer: _answer.text, newPassword: _pwd.text);
      ok = true;
    }, success: 'Mot de passe changé. Tu peux te connecter.');
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final (subtitle, body) = switch (_step) {
      _Step.email => ('Saisis l\'email de ton compte.', _emailStep()),
      _Step.method => ('Comment veux-tu recevoir ton code ?', _methodStep()),
      _Step.code => (
          _channel == ResetChannel.email
              ? 'Saisis le code à 6 chiffres envoyé à ${_target!.maskedEmail}.'
              : 'Saisis le code à 6 chiffres reçu par SMS au ${InfobipSmsSender.mask(_target!.phone!)}.',
          _codeStep()
        ),
      _Step.question => ('Réponds à ta question de sécurité.', _questionStep()),
    };
    return PopScope(
      canPop: _step == _Step.email,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _step = _step == _Step.method ? _Step.email : _Step.method);
      },
      child: AuthScaffold(
        showBack: true,
        title: 'Mot de passe oublié',
        subtitle: subtitle,
        child: Form(key: _form, child: body),
      ),
    );
  }

  Widget _emailStep() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          validator: Validators.email,
          decoration: const InputDecoration(
              labelText: 'Email du compte', prefixIcon: Icon(Icons.alternate_email)),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _findAccount,
          child: _busy ? const _Loader() : const Text('Continuer'),
        ),
      ]);

  Widget _methodStep() {
    final t = _target!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _MethodTile(
        icon: Icons.mark_email_unread_outlined,
        title: 'Recevoir un code par email',
        subtitle: t.maskedEmail,
        enabled: !_busy,
        onTap: () => _sendCode(ResetChannel.email),
      ),
      _MethodTile(
        icon: Icons.sms_outlined,
        title: 'Recevoir un code par SMS',
        subtitle: !t.hasPhone
            ? 'Aucun numéro sur ce compte'
            : PasswordResetService.smsDemoMode
                ? '${InfobipSmsSender.mask(t.phone!)} · mode démo'
                : InfobipSmsSender.mask(t.phone!),
        enabled: t.hasPhone && !_busy,
        onTap: () => _sendCode(ResetChannel.sms),
      ),
      if (t.hasSecurityQuestion)
        _MethodTile(
          icon: Icons.shield_outlined,
          title: 'Répondre à ma question de sécurité',
          subtitle: 'Sans email ni SMS',
          enabled: !_busy,
          onTap: () => setState(() {
            _answer.clear();
            _pwd.clear();
            _step = _Step.question;
          }),
        ),
      if (_busy) const Padding(padding: EdgeInsets.all(16), child: Center(child: _Loader(dark: true))),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _busy ? null : () => setState(() => _step = _Step.email),
        child: const Text('Utiliser un autre email'),
      ),
    ]);
  }

  Widget _codeStep() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextFormField(
          controller: _code,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
              fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 10),
          validator: (v) => (v ?? '').length == 6 ? null : 'Le code contient 6 chiffres',
          decoration: const InputDecoration(counterText: '', hintText: '••••••'),
        ),
        const SizedBox(height: 14),
        PasswordField(
            controller: _pwd,
            label: 'Nouveau mot de passe',
            validator: PasswordHasher.validate),
        PasswordStrengthMeter(controller: _pwd),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _confirmCode,
          child: _busy ? const _Loader() : const Text('Changer le mot de passe'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: (_busy || _cooldown > 0) ? null : () => _sendCode(_channel!),
          child: Text(_cooldown > 0
              ? 'Renvoyer le code dans $_cooldown s'
              : 'Renvoyer le code'),
        ),
        TextButton(
          onPressed: _busy ? null : () => setState(() => _step = _Step.method),
          child: const Text('Choisir une autre méthode'),
        ),
        const SizedBox(height: 4),
        const Text('Le code expire 10 minutes après l\'envoi.',
            textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
      ]);

  Widget _questionStep() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.saffron.withValues(alpha: .16),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(children: [
            const Icon(Icons.help_outline, color: AppColors.olive),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_target!.securityQuestion!,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _answer,
          validator: Validators.required,
          decoration: const InputDecoration(labelText: 'Ta réponse'),
        ),
        const SizedBox(height: 14),
        PasswordField(
            controller: _pwd,
            label: 'Nouveau mot de passe',
            validator: PasswordHasher.validate),
        PasswordStrengthMeter(controller: _pwd),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _busy ? null : _confirmQuestion,
          child: _busy ? const _Loader() : const Text('Changer le mot de passe'),
        ),
        TextButton(
          onPressed: _busy ? null : () => setState(() => _step = _Step.method),
          child: const Text('Choisir une autre méthode'),
        ),
      ]);
}

class _MethodTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;
  const _MethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          enabled: enabled,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: CircleAvatar(
            backgroundColor: AppColors.saffron.withValues(alpha: .2),
            child: Icon(icon, color: AppColors.olive),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: enabled ? onTap : null,
        ),
      );
}

class _Loader extends StatelessWidget {
  final bool dark;
  const _Loader({this.dark = false});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 22,
        width: 22,
        child: CircularProgressIndicator(
            strokeWidth: 2.4, color: dark ? AppColors.olive : Colors.white),
      );
}
