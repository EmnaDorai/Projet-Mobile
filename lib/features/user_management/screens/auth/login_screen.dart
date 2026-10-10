import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_exception.dart';
import '../../services/biometric_service.dart';
import '../../services/otp_service.dart';
import '../../widgets/auth_scaffold.dart';
import '../../widgets/common_widgets.dart';
import 'forgot_password_screen.dart';
import 'otp_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _bioReady = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.read<AuthProvider>().consumeSessionExpired()) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Session expirée après 30 min d\'inactivité. '
                'Reconnecte-toi.')));
      }
    });
  }

  /// Affiche le bouton biométrique si le téléphone le permet ET qu'un compte
  /// l'a activé dans son profil.
  Future<void> _checkBiometric() async {
    final bio = BiometricService();
    final ready = await bio.enrolledUserId() != null && await bio.isAvailable();
    if (mounted) setState(() => _bioReady = ready);
  }

  Future<void> _loginWith(Future<void> Function() action) async {
    setState(() => _loading = true);
    await runWithFeedback(context, action);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final email = _email.text;
    final password = _password.text;
    try {
      // La redirection selon le rôle est faite par RoleRouter (écoute AuthProvider).
      await auth.login(email, password);
    } on EmailNotVerifiedException catch (e) {
      _openOtp(e.userId, e.email, OtpPurpose.verifyEmail, (ctx, code) async {
        await auth.verifyEmail(e.userId, code);
        if (ctx.mounted) Navigator.pop(ctx);
        await auth.login(email, password);
      });
    } on TwoFactorRequiredException catch (e) {
      _openOtp(e.userId, e.email, OtpPurpose.twoFactor, (ctx, code) async {
        await auth.completeTwoFactor(e.userId, code);
        if (ctx.mounted) Navigator.pop(ctx);
      });
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), backgroundColor: Colors.red));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  void _openOtp(int userId, String email, OtpPurpose purpose,
      Future<void> Function(BuildContext, String) onVerified) {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtpScreen(
            userId: userId, email: email, purpose: purpose, onVerified: onVerified),
      ),
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      large: true,
      title: 'Connexion',
      subtitle: 'Retrouve tes commandes et ton profil.',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              validator: Validators.email,
              decoration: const InputDecoration(
                  labelText: 'Email', prefixIcon: Icon(Icons.alternate_email)),
            ),
            const SizedBox(height: 14),
            PasswordField(controller: _password),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                child: const Text('Mot de passe oublié ?'),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: Colors.white))
                  : const Text('Se connecter'),
            ),
            if (_bioReady) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loading
                    ? null
                    : () => _loginWith(
                        () => context.read<AuthProvider>().loginWithBiometric()),
                icon: const Icon(Icons.fingerprint, size: 26),
                label: const Text('Empreinte ou visage'),
              ),
            ],
            const SizedBox(height: 12),
            // Icône Google fournie par la bibliothèque d'icônes Font Awesome.
            OutlinedButton.icon(
              onPressed: _loading
                  ? null
                  : () => _loginWith(() => context.read<AuthProvider>().loginWithGoogle()),
              icon: const FaIcon(FontAwesomeIcons.google,
                  size: 20, color: Color(0xFF4285F4)),
              label: const Text('Continuer avec Google'),
            ),
            const SizedBox(height: 28),
            const Row(children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('Nouveau sur Bnin ?',
                    style: TextStyle(color: AppColors.muted)),
              ),
              Expanded(child: Divider()),
            ]),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
              child: const Text('Créer un compte'),
            ),
          ],
        ),
      ),
    );
  }
}
