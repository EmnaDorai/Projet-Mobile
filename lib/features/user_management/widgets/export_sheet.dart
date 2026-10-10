import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../services/export_service.dart';
import 'common_widgets.dart';

/// Demande « Télécharger » ou « Partager », lance l'export, puis propose
/// d'ouvrir le fichier téléchargé.
Future<void> exportWithChoice(
  BuildContext context, {
  required String title,
  required Future<String?> Function(ExportMode mode) run,
}) async {
  final mode = await showModalBottomSheet<ExportMode>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(title, style: Theme.of(c).textTheme.titleMedium),
        ),
        ListTile(
          leading: const Icon(Icons.download_outlined),
          title: const Text('Télécharger'),
          subtitle: const Text('Enregistrer dans le dossier Téléchargements'),
          onTap: () => Navigator.pop(c, ExportMode.download),
        ),
        ListTile(
          leading: const Icon(Icons.share_outlined),
          title: const Text('Partager'),
          subtitle: const Text('Gmail, Drive, WhatsApp…'),
          onTap: () => Navigator.pop(c, ExportMode.share),
        ),
        const SizedBox(height: 8),
      ]),
    ),
  );
  if (mode == null || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  String? path;
  final ok = await runWithFeedback(context, () async => path = await run(mode));
  final saved = path;
  if (!ok || saved == null) return;
  messenger.showSnackBar(SnackBar(
    duration: const Duration(seconds: 6),
    content: Text(saved.contains('/Download/')
        ? 'Enregistré dans Téléchargements :\n${saved.split('/').last}'
        : 'Enregistré :\n$saved'),
    action: SnackBarAction(label: 'Ouvrir', onPressed: () => OpenFilex.open(saved)),
  ));
}
