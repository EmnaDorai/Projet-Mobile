import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/profile_service.dart';
import '../../widgets/common_widgets.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _service = ProfileService();
  final _form = GlobalKey<FormState>();
  late final _user = context.read<AuthProvider>().currentUser!;
  late final _nom = TextEditingController(text: _user.nom);
  late final _prenom = TextEditingController(text: _user.prenom);
  late final _email = TextEditingController(text: _user.email);
  late final _tel = TextEditingController(text: _user.telephone ?? '');
  late String? _photo = _user.photo;

  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await ImagePicker()
        .pickImage(source: source, maxWidth: 600, imageQuality: 80);
    if (picked == null) return;
    final saved = await _service.savePhoto(_user.id!, picked.path);
    setState(() => _photo = saved);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await runWithFeedback(context, () async {
      final updated = await _service.updateProfile(_user.copyWith(
        nom: _nom.text.trim(),
        prenom: _prenom.text.trim(),
        email: _email.text.trim(),
        telephone: _tel.text.trim(),
        photo: _photo,
      ));
      auth.setUser(updated);
    }, success: 'Profil mis à jour');
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    for (final c in [_nom, _prenom, _email, _tel]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier le profil')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Center(
            child: Stack(children: [
              UserAvatar(user: _user.copyWith(photo: _photo), radius: 52),
              Positioned(
                right: 0,
                bottom: 0,
                child: IconButton.filled(
                  icon: const Icon(Icons.camera_alt, size: 18),
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    builder: (c) => SafeArea(
                      child: Wrap(children: [
                        ListTile(
                          leading: const Icon(Icons.photo_camera),
                          title: const Text('Prendre une photo'),
                          onTap: () {
                            Navigator.pop(c);
                            _pickPhoto(ImageSource.camera);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.photo_library),
                          title: const Text('Choisir dans la galerie'),
                          onTap: () {
                            Navigator.pop(c);
                            _pickPhoto(ImageSource.gallery);
                          },
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 24),
          TextFormField(
              controller: _prenom,
              validator: Validators.required,
              decoration: const InputDecoration(labelText: 'Prénom')),
          const SizedBox(height: 14),
          TextFormField(
              controller: _nom,
              validator: Validators.required,
              decoration: const InputDecoration(labelText: 'Nom')),
          const SizedBox(height: 14),
          TextFormField(
              controller: _email,
              validator: Validators.email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 14),
          TextFormField(
              controller: _tel,
              validator: Validators.phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Téléphone')),
          const SizedBox(height: 28),
          FilledButton(onPressed: _save, child: const Text('Enregistrer')),
        ]),
      ),
    );
  }
}
