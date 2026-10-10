import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../dao/activity_log_dao.dart';
import '../dao/address_dao.dart';
import '../dao/history_repository.dart';
import '../dao/preference_dao.dart';
import '../models/activity_log.dart';
import '../models/history_item.dart';
import '../models/user.dart';
import '../widgets/common_widgets.dart' show formatDate;
import 'loyalty_service.dart';

enum ExportMode { download, share }

/// Exports PDF / CSV : enregistrés dans le dossier Téléchargements du
/// téléphone, ou partagés (Gmail, Drive, WhatsApp…).
/// Chaque export retourne le chemin du fichier enregistré (null si partagé).
class ExportService {
  static const _olive = PdfColor.fromInt(0xFF1F2B1D);

  // ───────── « Exporter mes données » (droit d'accès RGPD) ─────────
  Future<String?> exportMyData(User u, {ExportMode mode = ExportMode.download}) async {
    final addresses = await AddressDao().getByUser(u.id!);
    final pref = await PreferenceDao().get(u.id!);
    final orders = <HistoryItem>[];
    LoyaltyInfo? loyalty;
    if (u.role == UserRole.client) {
      for (var page = 0; page < 10; page++) {
        final p = await HistoryRepository().getClientOrders(u.id!, page: page);
        orders.addAll(p);
        if (p.length < HistoryRepository.pageSize) break;
      }
      loyalty = await LoyaltyService().get(u.id!);
    }
    final logs = (await ActivityLogDao().getByUser(u.id!, limit: 30));

    final doc = pw.Document(title: 'Mes données Bnin', author: 'Bnin');
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (_) => _header('Mes données personnelles'),
      footer: _footer,
      build: (_) => [
        _section('Profil'),
        _kv([
          ['Nom', u.nomComplet],
          ['Email', u.email],
          ['Téléphone', u.telephone ?? '-'],
          ['Rôle', u.role.label],
          ['Statut', u.statut.label],
          ['Inscrit le', formatDate(u.dateCreation)],
        ]),
        _section('Préférences'),
        _kv([
          ['Allergies', (pref.allergies ?? '').isEmpty ? 'Aucune' : pref.allergies!],
          ['Langue', pref.langue],
          ['Notifications', pref.notifications ? 'Oui' : 'Non'],
        ]),
        if (addresses.isNotEmpty) ...[
          _section('Adresses'),
          _table(['Libellé', 'Adresse', 'Par défaut'], [
            for (final a in addresses) [a.libelle, a.complete, a.parDefaut ? 'Oui' : ''],
          ]),
        ],
        if (loyalty != null) ...[
          _section('Fidélité'),
          _kv([
            ['Points', '${loyalty.total}'],
            ['Niveau', loyalty.level.label],
            ['Code de parrainage', loyalty.codeParrainage ?? '-'],
          ]),
        ],
        if (u.role == UserRole.client) ...[
          _section('Historique des commandes (${orders.length})'),
          if (orders.isEmpty)
            pw.Text('Aucune commande.')
          else
            _table(['N°', 'Date', 'Statut', 'Montant'], [
              for (final o in orders)
                [
                  '#${o.id}',
                  formatDate(o.date, withTime: true),
                  o.statut,
                  o.montant == null ? '-' : '${o.montant!.toStringAsFixed(2)} DT',
                ],
            ]),
        ],
        _section('Activité récente'),
        _table(['Date', 'Action', 'Détails'], [
          for (final l in logs)
            [formatDate(l.date, withTime: true), _logLabel(l.action), l.details ?? ''],
        ]),
      ],
    ));
    final path = await _deliver(await doc.save(), 'mes_donnees_bnin', 'pdf',
        'application/pdf', 'Mes données Bnin', mode);
    await ActivityLogDao().log(u.id, LogAction.exportData, 'PDF');
    return path;
  }

  // ───────── Liste des utilisateurs (Admin) ─────────
  Future<String?> exportUsersPdf(List<User> users,
      {int? adminId, ExportMode mode = ExportMode.download}) async {
    final doc = pw.Document(title: 'Utilisateurs Bnin', author: 'Bnin');
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(28),
      header: (_) => _header('Liste des utilisateurs (${users.length})'),
      footer: _footer,
      build: (_) => [
        _table(['Nom', 'Email', 'Téléphone', 'Rôle', 'Statut', 'Inscription'], [
          for (final u in users)
            [
              u.nomComplet,
              u.email,
              u.telephone ?? '',
              u.role.label,
              u.statut.label,
              formatDate(u.dateCreation),
            ],
        ]),
      ],
    ));
    final path = await _deliver(await doc.save(), 'utilisateurs_bnin', 'pdf',
        'application/pdf', 'Utilisateurs Bnin', mode);
    await ActivityLogDao().log(adminId, LogAction.exportData, 'Utilisateurs PDF');
    return path;
  }

  /// CSV séparé par « ; » (ouverture directe dans Excel en français).
  Future<String?> exportUsersCsv(List<User> users,
      {int? adminId, ExportMode mode = ExportMode.download}) async {
    String cell(String? v) => '"${(v ?? '').replaceAll('"', '""')}"';
    final lines = [
      'Nom;Prénom;Email;Téléphone;Rôle;Statut;Date d\'inscription',
      for (final u in users)
        [
          cell(u.nom),
          cell(u.prenom),
          cell(u.email),
          cell(u.telephone),
          cell(u.role.label),
          cell(u.statut.label),
          cell(formatDate(u.dateCreation)),
        ].join(';'),
    ];
    // BOM UTF-8 : Excel affiche correctement les accents.
    final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode(lines.join('\r\n'))];
    final path = await _deliver(
        bytes, 'utilisateurs_bnin', 'csv', 'text/csv', 'Utilisateurs Bnin', mode);
    await ActivityLogDao().log(adminId, LogAction.exportData, 'Utilisateurs CSV');
    return path;
  }

  // ───────── Outils ─────────
  /// Télécharger : fichier dans « Téléchargements » (Android 11+ autorise
  /// l'écriture directe dans ce dossier, sans permission).
  /// Partager : fichier temporaire + feuille de partage.
  Future<String?> _deliver(List<int> bytes, String baseName, String ext, String mime,
      String subject, ExportMode mode) async {
    final stamp = DateTime.now()
        .toIso8601String()
        .substring(0, 16)
        .replaceAll(RegExp(r'[-:T]'), '');
    final name = '${baseName}_$stamp.$ext';

    if (mode == ExportMode.download) {
      try {
        final file = File('${(await _downloadDir()).path}/$name');
        await file.writeAsBytes(bytes, flush: true);
        return file.path;
      } on FileSystemException {
        // Ancien Android sans accès direct : dossier de l'app.
        final dir = await getExternalStorageDirectory() ??
            await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$name');
        await file.writeAsBytes(bytes, flush: true);
        return file.path;
      }
    }
    final tmp = await getTemporaryDirectory();
    final file = File('${tmp.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: mime)],
      subject: subject,
    ));
    return null;
  }

  /// Dossier public « Download » sur Android ; sinon dossier de l'app.
  Future<Directory> _downloadDir() async {
    if (Platform.isAndroid) {
      final d = Directory('/storage/emulated/0/Download');
      if (await d.exists()) return d;
    }
    return await getExternalStorageDirectory() ??
        await getApplicationDocumentsDirectory();
  }

  pw.Widget _header(String title) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 16),
        padding: const pw.EdgeInsets.all(14),
        decoration: const pw.BoxDecoration(
            color: _olive, borderRadius: pw.BorderRadius.all(pw.Radius.circular(8))),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('bnin',
              style: const pw.TextStyle(
                  color: PdfColors.white, fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.Text(title, style: const pw.TextStyle(color: PdfColors.white, fontSize: 13)),
        ]),
      );

  pw.Widget _footer(pw.Context c) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
            'Généré le ${formatDate(DateTime.now(), withTime: true)} - page ${c.pageNumber}/${c.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
      );

  pw.Widget _section(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
        child: pw.Text(t,
            style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _olive)),
      );

  pw.Widget _kv(List<List<String>> rows) => pw.Table(
        columnWidths: const {0: pw.FixedColumnWidth(140)},
        children: [
          for (final r in rows)
            pw.TableRow(children: [
              pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Text(r[0], style: const pw.TextStyle(color: PdfColors.grey700))),
              pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Text(r[1])),
            ]),
        ],
      );

  pw.Widget _table(List<String> headers, List<List<String>> data) =>
      pw.TableHelper.fromTextArray(
        headers: headers,
        data: data,
        headerStyle: const pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold),
        headerDecoration: const pw.BoxDecoration(color: _olive),
        cellStyle: const pw.TextStyle(fontSize: 9.5),
        cellAlignment: pw.Alignment.centerLeft,
        oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      );

  static String _logLabel(String a) => switch (a) {
        LogAction.login => 'Connexion',
        LogAction.logout => 'Déconnexion',
        LogAction.loginFailed => 'Échec de connexion',
        LogAction.register => 'Inscription',
        LogAction.updateProfile => 'Profil modifié',
        LogAction.changePassword => 'Mot de passe changé',
        _ => a,
      };
}
