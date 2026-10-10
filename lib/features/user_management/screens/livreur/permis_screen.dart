import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../dao/activity_log_dao.dart';
import '../../dao/delivery_agent_dao.dart';
import '../../models/activity_log.dart';
import '../../widgets/common_widgets.dart';

/// Photo du permis de conduire, vérifiée par l'administrateur avant
/// de valider le compte du livreur.
class PermisScreen extends StatefulWidget {
  final int userId;
  const PermisScreen({super.key, required this.userId});
  @override
  State<PermisScreen> createState() => _PermisScreenState();
}

class _PermisScreenState extends State<PermisScreen> {
  final _dao = DeliveryAgentDao();
  String? _path;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _dao.getProfile(widget.userId).then((p) {
      if (mounted) {
        setState(() {
          _path = p.permisPhoto;
          _loaded = true;
        });
      }
    });
  }

  Future<void> _pick(ImageSource source) async {
    final img = await ImagePicker()
        .pickImage(source: source, imageQuality: 75, maxWidth: 1600);
    if (img == null) return;
    // Copie dans le dossier de l'app (le cache peut être vidé par Android).
    final dir = await getApplicationDocumentsDirectory();
    final dest = '${dir.path}/permis_${widget.userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await File(img.path).copy(dest);
    await _dao.setPermisPhoto(widget.userId, dest);
    await ActivityLogDao().log(widget.userId, LogAction.uploadDocument, 'Permis de conduire');
    if (!mounted) return;
    setState(() => _path = dest);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Permis enregistré')));
  }

  @override
  Widget build(BuildContext context) {
    final hasFile = _path != null && File(_path!).existsSync();
    return Scaffold(
      appBar: AppBar(title: const Text('Permis de conduire')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(20), children: [
              Card(
                color: hasFile ? Colors.green.shade50 : Colors.orange.shade50,
                child: ListTile(
                  leading: Icon(hasFile ? Icons.verified : Icons.pending_actions,
                      color: hasFile ? Colors.green : Colors.orange),
                  title: Text(hasFile ? 'Document fourni' : 'Document manquant'),
                  subtitle: const Text(
                      'L\'administrateur vérifie ton permis avant d\'activer ton compte.'),
                ),
              ),
              const SizedBox(height: 16),
              if (hasFile)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.file(File(_path!), fit: BoxFit.cover),
                )
              else
                const EmptyState(
                    icon: Icons.badge_outlined,
                    message: 'Prends en photo ton permis (recto).'),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _pick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Prendre une photo'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choisir dans la galerie'),
              ),
            ]),
    );
  }
}
