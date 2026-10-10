import 'dart:math';

import '../../../core/config/api_config.dart';
import '../../../core/database/database_helper.dart';
import '../dao/activity_log_dao.dart';
import '../dao/user_dao.dart';
import '../models/activity_log.dart';
import 'auth_exception.dart';
import 'auth_service.dart';
import 'message_senders.dart';
import 'password_hasher.dart';

enum ResetChannel { email, sms }

/// Compte trouvé pour la réinitialisation (données affichables uniquement).
class ResetTarget {
  final int userId;
  final String name;
  final String email;
  final String? phone;
  final String? securityQuestion;
  const ResetTarget({
    required this.userId,
    required this.name,
    required this.email,
    this.phone,
    this.securityQuestion,
  });

  bool get hasPhone => phone != null && phone!.trim().isNotEmpty;
  bool get hasSecurityQuestion =>
      securityQuestion != null && securityQuestion!.isNotEmpty;

  /// « e••••81@gmail.com »
  String get maskedEmail {
    final at = email.indexOf('@');
    if (at <= 2) return email;
    return '${email[0]}••••${email.substring(at - 2)}';
  }
}

/// Mot de passe oublié par code à 6 chiffres envoyé par email ou SMS.
/// Le code est stocké haché, expire après 10 min, 5 essais maximum.
class PasswordResetService {
  static const codeValidity = Duration(minutes: 10);
  static const resendDelay = Duration(seconds: 60);
  static const maxAttempts = 5;

  final DatabaseHelper _helper;
  final UserDao _users;
  final ActivityLogDao _logs;
  final AuthService _auth;
  final EmailJsSender _email;
  final InfobipSmsSender _sms;

  PasswordResetService({
    DatabaseHelper? helper,
    UserDao? users,
    ActivityLogDao? logs,
    AuthService? auth,
    EmailJsSender? email,
    InfobipSmsSender? sms,
  })  : _helper = helper ?? DatabaseHelper.instance,
        _users = users ?? UserDao(),
        _logs = logs ?? ActivityLogDao(),
        _auth = auth ?? AuthService(),
        _email = email ?? EmailJsSender(),
        _sms = sms ?? InfobipSmsSender();

  Future<ResetTarget> findAccount(String email) async {
    final row = await _users.getCredentialsByEmail(email);
    if (row == null) {
      throw const AuthException('Aucun compte n\'est associé à cet email.');
    }
    if (row['statut'] == 'BLOQUE') {
      throw const AuthException(
          'Ce compte est bloqué. Contacte l\'administrateur.');
    }
    final hasAnswer = row['reponse_securite'] != null &&
        (row['reponse_securite'] as String).isNotEmpty;
    return ResetTarget(
      userId: row['id'] as int,
      name: '${row['prenom']} ${row['nom']}',
      email: row['email'] as String,
      phone: row['telephone'] as String?,
      securityQuestion: hasAnswer ? row['question_securite'] as String? : null,
    );
  }

  /// SMS simulé tant qu'Infobip n'est pas configuré (numéros tunisiens
  /// refusés par les comptes d'essai des fournisseurs).
  static bool get smsDemoMode => !ApiConfig.infobipConfigured;

  /// Envoie le code. Retourne le code uniquement en mode démo SMS
  /// (pour l'afficher dans une fausse notification), sinon null.
  Future<String?> sendCode(ResetTarget t, ResetChannel channel) async {
    if (channel == ResetChannel.sms && !t.hasPhone) {
      throw const AuthException('Aucun numéro de téléphone sur ce compte.');
    }
    final db = await _helper.database;

    // Anti-spam : un envoi par minute.
    final last = await db.query('password_resets',
        where: 'user_id = ?',
        whereArgs: [t.userId],
        orderBy: 'created_at DESC',
        limit: 1);
    if (last.isNotEmpty) {
      final at = DateTime.parse(last.first['created_at'] as String);
      final wait = resendDelay - DateTime.now().difference(at);
      if (!wait.isNegative) {
        throw AuthException(
            'Patiente ${wait.inSeconds + 1} s avant de demander un nouveau code.');
      }
    }

    final code = (Random.secure().nextInt(900000) + 100000).toString();
    final now = DateTime.now();

    // Un seul code valide à la fois.
    await db.update('password_resets', {'used': 1},
        where: 'user_id = ? AND used = 0', whereArgs: [t.userId]);
    final id = await db.insert('password_resets', {
      'user_id': t.userId,
      'code_hash': PasswordHasher.hashAnswer(code),
      'channel': channel == ResetChannel.email ? 'EMAIL' : 'SMS',
      'expires_at': now.add(codeValidity).toIso8601String(),
      'created_at': now.toIso8601String(),
    });

    final demo = channel == ResetChannel.sms && smsDemoMode;
    try {
      if (channel == ResetChannel.email) {
        await _email.sendResetCode(toEmail: t.email, toName: t.name, code: code);
      } else if (!demo) {
        await _sms.sendResetCode(phone: t.phone!, code: code);
      }
    } catch (e) {
      // Envoi échoué : on supprime le code pour permettre un nouvel essai.
      await db.delete('password_resets', where: 'id = ?', whereArgs: [id]);
      rethrow;
    }
    await _logs.log(t.userId, LogAction.resetCodeSent,
        channel == ResetChannel.email ? 'Par email' : (demo ? 'Par SMS (démo)' : 'Par SMS'));
    return demo ? code : null;
  }

  Future<void> resetWithCode({
    required int userId,
    required String code,
    required String newPassword,
  }) async {
    final db = await _helper.database;
    final rows = await db.query('password_resets',
        where: 'user_id = ? AND used = 0',
        whereArgs: [userId],
        orderBy: 'created_at DESC',
        limit: 1);
    if (rows.isEmpty) {
      throw const AuthException('Aucun code en cours. Demande un nouveau code.');
    }
    final r = rows.first;
    final id = r['id'] as int;
    if (DateTime.now().isAfter(DateTime.parse(r['expires_at'] as String))) {
      await db.update('password_resets', {'used': 1}, where: 'id = ?', whereArgs: [id]);
      throw const AuthException('Ce code a expiré. Demande un nouveau code.');
    }
    final attempts = (r['attempts'] as int) + 1;
    if (!PasswordHasher.verifyAnswer(code.trim(), r['code_hash'] as String)) {
      final blocked = attempts >= maxAttempts;
      await db.update('password_resets', {'attempts': attempts, 'used': blocked ? 1 : 0},
          where: 'id = ?', whereArgs: [id]);
      throw AuthException(blocked
          ? 'Trop d\'essais. Demande un nouveau code.'
          : 'Code incorrect (${maxAttempts - attempts} essai(s) restant(s)).');
    }
    // Vérifie le nouveau mot de passe AVANT de consommer le code.
    final err = PasswordHasher.validate(newPassword);
    if (err != null) throw AuthException(err);
    await _auth.forceSetPassword(userId, newPassword);
    await db.update('password_resets', {'used': 1}, where: 'id = ?', whereArgs: [id]);
    // Un code reçu par email prouve aussi que l'adresse est valide.
    if (r['channel'] == 'EMAIL') await _users.setEmailVerified(userId);
    await _logs.log(userId, LogAction.resetPassword, 'Par code');
  }
}
