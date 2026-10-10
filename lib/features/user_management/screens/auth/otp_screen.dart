import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/otp_service.dart';
import '../../widgets/auth_scaffold.dart';
import '../../widgets/common_widgets.dart';

/// Saisie d'un code à 6 chiffres reçu par email :
/// vérification de l'email (inscription) ou double authentification.
/// [onVerified] est appelé une fois le code accepté.
class OtpScreen extends StatefulWidget {
  final int userId;
  final String email;
  final OtpPurpose purpose;
  final Future<void> Function(BuildContext context, String code) onVerified;
  const OtpScreen({
    super.key,
    required this.userId,
    required this.email,
    required this.purpose,
    required this.onVerified,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _busy = false;
  int _cooldown = 0;
  Timer? _timer;

  bool get _isTwoFactor => widget.purpose == OtpPurpose.twoFactor;

  @override
  void initState() {
    super.initState();
    // Vérification d'email : on envoie le code dès l'ouverture.
    // (Pour la 2FA, le code est déjà parti au moment de la connexion.)
    if (!_isTwoFactor) WidgetsBinding.instance.addPostFrameCallback((_) => _send());
    _startCooldown();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldown = OtpService.resendDelay.inSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  Future<void> _send({bool resend = false}) async {
    setState(() => _busy = true);
    final ok = await runWithFeedback(
        context,
        () => context
            .read<AuthProvider>()
            .sendOtp(widget.userId, widget.purpose, resend: resend),
        success: resend ? 'Nouveau code envoyé' : null);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok && resend) _startCooldown();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    await runWithFeedback(context, () => widget.onVerified(context, _code.text));
    if (mounted) setState(() => _busy = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      title: _isTwoFactor ? 'Code de connexion' : 'Vérifie ton email',
      subtitle: 'Saisis le code à 6 chiffres envoyé à ${widget.email}.',
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Icon(_isTwoFactor ? Icons.verified_user_outlined : Icons.mark_email_unread_outlined,
              size: 56, color: AppColors.oliveSoft),
          const SizedBox(height: 20),
          TextFormField(
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: 10),
            validator: (v) => (v ?? '').length == 6 ? null : 'Le code contient 6 chiffres',
            decoration: const InputDecoration(counterText: '', hintText: '••••••'),
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Vérification…' : 'Valider'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: (_busy || _cooldown > 0) ? null : () => _send(resend: true),
            child: Text(_cooldown > 0
                ? 'Renvoyer le code dans $_cooldown s'
                : 'Renvoyer le code'),
          ),
          const Text('Pense à regarder dans les spams. Le code expire après 10 minutes.',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
        ]),
      ),
    );
  }
}
