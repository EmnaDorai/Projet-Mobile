import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/geocoding_service.dart';
import '../../services/otp_service.dart';
import '../../services/password_hasher.dart';
import '../../../../core/theme/app_theme.dart';
import '../../widgets/auth_scaffold.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/password_strength.dart';
import '../common/map_picker_screen.dart';
import 'otp_screen.dart';

/// Inscription : le visiteur choisit son rôle (Client, Livreur ou Manager).
/// Les comptes Livreur et Manager attendent la validation de l'administrateur.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _prenom = TextEditingController();
  final _email = TextEditingController();
  final _tel = TextEditingController();
  final _pwd = TextEditingController();
  final _pwd2 = TextEditingController();
  final _answer = TextEditingController();
  final _rue = TextEditingController();
  final _ville = TextEditingController();
  final _parrain = TextEditingController();
  UserRole _role = UserRole.client;
  String _vehicule = 'Moto';
  String? _permisPath;
  String _question = AuthService.securityQuestions.first;
  String _libelle = 'Maison';
  double? _lat;
  double? _lng;
  bool _locating = false;
  bool _loading = false;

  /// Remplit l'adresse à partir de la position GPS (API Nominatim).
  Future<void> _locate() async {
    setState(() => _locating = true);
    await runWithFeedback(context, () async {
      final geo = GeocodingService();
      final pos = await geo.currentPosition();
      final addr = await geo.reverse(pos.latitude, pos.longitude);
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        if (addr.street != null) _rue.text = addr.street!;
        if (addr.city != null) _ville.text = addr.city!;
      });
    });
    if (mounted) setState(() => _locating = false);
  }

  /// Position choisie sur la carte OpenStreetMap.
  Future<void> _pickOnMap() async {
    final p = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MapPickerScreen(initial: _lat == null ? null : LatLng(_lat!, _lng!)),
      ),
    );
    if (p == null || !mounted) return;
    setState(() => _locating = true);
    final addr = await GeocodingService().reverse(p.latitude, p.longitude);
    if (!mounted) return;
    setState(() {
      _locating = false;
      _lat = p.latitude;
      _lng = p.longitude;
      if (addr.street != null) _rue.text = addr.street!;
      if (addr.city != null) _ville.text = addr.city!;
    });
  }

  Future<void> _pickPermis() async {
    final img = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 75, maxWidth: 1600);
    if (img != null && mounted) setState(() => _permisPath = img.path);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_role == UserRole.livreur && _permisPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ajoute la photo de ton permis de conduire'),
          backgroundColor: Colors.red));
      return;
    }
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final isClient = _role == UserRole.client;
    final role = _role;
    final email = _email.text;
    final password = _pwd.text;
    ({int userId, bool needsVerification, bool pending})? result;
    final ok = await runWithFeedback(
      context,
      () async => result = await auth.register(
            role: _role,
            typeVehicule: _role == UserRole.livreur ? _vehicule : null,
            permisPhotoPath: _role == UserRole.livreur ? _permisPath : null,
            nom: _nom.text,
            prenom: _prenom.text,
            email: email,
            telephone: _tel.text.isEmpty ? null : _tel.text,
            password: password,
            securityQuestion: _question,
            securityAnswer: _answer.text,
            addressLabel: isClient ? _libelle : null,
            street: isClient ? _rue.text : null,
            city: isClient ? _ville.text : null,
            latitude: isClient ? _lat : null,
            longitude: isClient ? _lng : null,
            referralCode: isClient ? _parrain.text : null,
          ),
    );
    if (!mounted) return;
    setState(() => _loading = false);
    final r = result;
    if (!ok || r == null) return;

    if (r.needsVerification) {
      // Étape suivante : code reçu par email.
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpScreen(
            userId: r.userId,
            email: email.trim().toLowerCase(),
            purpose: OtpPurpose.verifyEmail,
            onVerified: (ctx, code) async {
              await auth.verifyEmail(r.userId, code);
              if (!r.pending) await auth.login(email, password);
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
          ),
        ),
      );
      if (!mounted) return;
      // Fermé sans vérifier : le code sera redemandé à la connexion.
      if (auth.currentUser == null && !r.pending) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }
    }
    if (r.pending) await _showPendingDialog(role);
    if (!mounted) return;
    if (auth.currentUser != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Compte créé avec succès')));
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _showPendingDialog(UserRole role) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.hourglass_top, color: AppColors.saffron, size: 36),
          title: const Text('Demande envoyée'),
          content: Text('Ton compte ${role.label} a été créé. L\'administrateur doit '
              'le valider avant ta première connexion. Tu recevras un email.'),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Compris')),
          ],
        ),
      );

  @override
  void dispose() {
    for (final c in [_nom, _prenom, _email, _tel, _pwd, _pwd2, _answer, _rue, _ville, _parrain]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);
    return AuthScaffold(
      showBack: true,
      title: 'Créer un compte',
      subtitle: 'Quelques infos, et c\'est parti.',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Je suis…', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<UserRole>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                    value: UserRole.client,
                    label: Text('Client'),
                    icon: Icon(Icons.person_outline)),
                ButtonSegment(
                    value: UserRole.livreur,
                    label: Text('Livreur'),
                    icon: Icon(Icons.delivery_dining)),
                ButtonSegment(
                    value: UserRole.manager,
                    label: Text('Manager'),
                    icon: Icon(Icons.storefront_outlined)),
              ],
              selected: {_role},
              onSelectionChanged: (s) => setState(() => _role = s.first),
            ),
            if (_role != UserRole.client) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.saffron.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline, color: AppColors.olive),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                        'Ce compte sera activé après validation par l\'administrateur.'),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _prenom,
                  validator: Validators.required,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Prénom'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _nom,
                  validator: Validators.required,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nom'),
                ),
              ),
            ]),
            gap,
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
              decoration: const InputDecoration(
                  labelText: 'Email', prefixIcon: Icon(Icons.alternate_email)),
            ),
            gap,
            TextFormField(
              controller: _tel,
              keyboardType: TextInputType.phone,
              validator: Validators.phone,
              decoration: const InputDecoration(
                  labelText: 'Téléphone (optionnel)',
                  prefixIcon: Icon(Icons.phone_outlined)),
            ),
            gap,
            if (_role == UserRole.livreur) ...[
              DropdownButtonFormField<String>(
                initialValue: _vehicule,
                decoration: const InputDecoration(
                    labelText: 'Type de véhicule',
                    prefixIcon: Icon(Icons.two_wheeler)),
                items: const ['Moto', 'Scooter', 'Vélo', 'Voiture']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => _vehicule = v!),
              ),
              gap,
              OutlinedButton.icon(
                onPressed: _pickPermis,
                icon: Icon(_permisPath == null ? Icons.badge_outlined : Icons.check_circle,
                    color: _permisPath == null ? null : AppColors.success),
                label: Text(_permisPath == null
                    ? 'Photo du permis de conduire'
                    : 'Permis ajouté (toucher pour changer)'),
              ),
              if (_permisPath != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(_permisPath!), height: 120, fit: BoxFit.cover),
                ),
              ],
              gap,
            ],
            PasswordField(controller: _pwd, validator: PasswordHasher.validate),
            PasswordStrengthMeter(controller: _pwd),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 6, 4, 0),
              child: Text('8 caractères min., une majuscule et un chiffre.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
            ),
            gap,
            PasswordField(
              controller: _pwd2,
              label: 'Confirmer le mot de passe',
              validator: (v) =>
                  v != _pwd.text ? 'Les mots de passe ne correspondent pas' : null,
            ),
            if (_role == UserRole.client) ...[
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Icon(Icons.location_on_outlined, color: AppColors.oliveSoft),
                    const SizedBox(width: 10),
                    Text('Adresse de livraison',
                        style: Theme.of(context).textTheme.titleMedium),
                  ]),
                  const SizedBox(height: 4),
                  const Text('Elle sera proposée par défaut à chaque commande.',
                      style: TextStyle(color: AppColors.muted)),
                  gap,
                  Wrap(spacing: 8, children: [
                    for (final l in const ['Maison', 'Travail', 'Autre'])
                      ChoiceChip(
                        label: Text(l),
                        selected: _libelle == l,
                        onSelected: (_) => setState(() => _libelle = l),
                      ),
                  ]),
                  gap,
                  OutlinedButton.icon(
                    onPressed: _locating ? null : _locate,
                    icon: _locating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Icon(_lat == null ? Icons.my_location : Icons.check_circle,
                            color: _lat == null ? null : AppColors.success),
                    label: Text(_lat == null
                        ? 'Utiliser ma position actuelle'
                        : 'Position enregistrée'),
                  ),
                  TextButton.icon(
                    onPressed: _locating ? null : _pickOnMap,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Choisir sur la carte'),
                  ),
                  gap,
                  TextFormField(
                    controller: _rue,
                    validator: Validators.required,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                        labelText: 'Rue et numéro',
                        prefixIcon: Icon(Icons.signpost_outlined)),
                  ),
                  gap,
                  TextFormField(
                    controller: _ville,
                    validator: Validators.required,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        labelText: 'Ville',
                        prefixIcon: Icon(Icons.location_city_outlined)),
                  ),
                ],
              ),
            ),
            ],
            if (_role == UserRole.client) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _parrain,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                    labelText: 'Code de parrainage (optionnel)',
                    helperText: 'Un ami t\'a invité ? +20 points de fidélité',
                    prefixIcon: Icon(Icons.card_giftcard_outlined)),
              ),
            ],
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    const Icon(Icons.shield_outlined, color: AppColors.oliveSoft),
                    const SizedBox(width: 10),
                    Text('Question de sécurité',
                        style: Theme.of(context).textTheme.titleMedium),
                  ]),
                  const SizedBox(height: 4),
                  const Text('Elle permet de récupérer ton mot de passe.',
                      style: TextStyle(color: AppColors.muted)),
                  gap,
                  DropdownButtonFormField<String>(
                    initialValue: _question,
                    isExpanded: true,
                    items: AuthService.securityQuestions
                        .map((q) => DropdownMenuItem(value: q, child: Text(q)))
                        .toList(),
                    onChanged: (v) => setState(() => _question = v!),
                  ),
                  gap,
                  TextFormField(
                    controller: _answer,
                    validator: Validators.required,
                    decoration: const InputDecoration(labelText: 'Ta réponse'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: Text(_loading ? 'Création…' : 'Créer mon compte'),
            ),
          ],
        ),
      ),
    );
  }
}
