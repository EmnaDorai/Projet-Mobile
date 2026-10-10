import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/common_widgets.dart';

class SecurityQuestionScreen extends StatefulWidget {
  const SecurityQuestionScreen({super.key});
  @override
  State<SecurityQuestionScreen> createState() => _SecurityQuestionScreenState();
}

class _SecurityQuestionScreenState extends State<SecurityQuestionScreen> {
  final _form = GlobalKey<FormState>();
  final _answer = TextEditingController();
  final _pwd = TextEditingController();
  late String _question;

  @override
  void initState() {
    super.initState();
    final current = context.read<AuthProvider>().currentUser!.questionSecurite;
    _question = AuthService.securityQuestions.contains(current)
        ? current!
        : AuthService.securityQuestions.first;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await runWithFeedback(context, () async {
      await AuthService().setSecurityQuestion(
          auth.currentUser!.id!, _pwd.text, _question, _answer.text);
      await auth.refresh();
    }, success: 'Question de sécurité enregistrée');
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _answer.dispose();
    _pwd.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Question de sécurité')),
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(20), children: [
            DropdownButtonFormField<String>(
              initialValue: _question,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Question'),
              items: AuthService.securityQuestions
                  .map((q) => DropdownMenuItem(value: q, child: Text(q)))
                  .toList(),
              onChanged: (v) => setState(() => _question = v!),
            ),
            const SizedBox(height: 14),
            TextFormField(
                controller: _answer,
                validator: Validators.required,
                decoration: const InputDecoration(labelText: 'Réponse')),
            const SizedBox(height: 14),
            PasswordField(controller: _pwd, label: 'Mot de passe actuel (confirmation)'),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: const Text('Enregistrer')),
          ]),
        ),
      );
}
