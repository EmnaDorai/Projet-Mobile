import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/admin_service.dart';
import '../../services/password_hasher.dart';
import '../../widgets/common_widgets.dart';

/// Création d'un compte Manager, Livreur (ou Admin) par l'administrateur.
class CreateUserScreen extends StatefulWidget {
  const CreateUserScreen({super.key});
  @override
  State<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends State<CreateUserScreen> {
  final _form = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _prenom = TextEditingController();
  final _email = TextEditingController();
  final _tel = TextEditingController();
  final _pwd = TextEditingController();
  UserRole _role = UserRole.livreur;
  String _vehicule = 'Moto';

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final adminId = context.read<AuthProvider>().currentUser!.id!;
    final ok = await runWithFeedback(
      context,
      () => AdminService().createUser(
        adminId: adminId,
        nom: _nom.text,
        prenom: _prenom.text,
        email: _email.text,
        telephone: _tel.text.isEmpty ? null : _tel.text,
        role: _role,
        password: _pwd.text,
        typeVehicule: _role == UserRole.livreur ? _vehicule : null,
      ),
      success: 'Compte ${_role.label} créé',
    );
    if (ok && mounted) Navigator.pop(context, true);
  }

  @override
  void dispose() {
    for (final c in [_nom, _prenom, _email, _tel, _pwd]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);
    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau compte')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Text('Rôle', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<UserRole>(
            segments: const [
              ButtonSegment(
                  value: UserRole.livreur,
                  label: Text('Livreur'),
                  icon: Icon(Icons.delivery_dining)),
              ButtonSegment(
                  value: UserRole.manager,
                  label: Text('Manager'),
                  icon: Icon(Icons.manage_accounts)),
              ButtonSegment(
                  value: UserRole.admin,
                  label: Text('Admin'),
                  icon: Icon(Icons.admin_panel_settings)),
            ],
            selected: {_role},
            onSelectionChanged: (s) => setState(() => _role = s.first),
          ),
          const SizedBox(height: 20),
          TextFormField(
              controller: _prenom,
              validator: Validators.required,
              decoration: const InputDecoration(labelText: 'Prénom')),
          gap,
          TextFormField(
              controller: _nom,
              validator: Validators.required,
              decoration: const InputDecoration(labelText: 'Nom')),
          gap,
          TextFormField(
              controller: _email,
              validator: Validators.email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email')),
          gap,
          TextFormField(
              controller: _tel,
              validator: Validators.phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Téléphone')),
          gap,
          if (_role == UserRole.livreur) ...[
            DropdownButtonFormField<String>(
              initialValue: _vehicule,
              decoration: const InputDecoration(labelText: 'Type de véhicule'),
              items: const ['Moto', 'Scooter', 'Vélo', 'Voiture']
                  .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                  .toList(),
              onChanged: (v) => setState(() => _vehicule = v!),
            ),
            gap,
          ],
          PasswordField(
              controller: _pwd,
              label: 'Mot de passe provisoire',
              validator: PasswordHasher.validate),
          const SizedBox(height: 6),
          const Text(
              'Communiquez ce mot de passe à l\'utilisateur ; il pourra le changer depuis son profil.',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          FilledButton(onPressed: _submit, child: const Text('Créer le compte')),
        ]),
      ),
    );
  }
}
