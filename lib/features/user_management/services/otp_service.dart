import 'dart:math';

import '../../../core/database/database_helper.dart';
import 'auth_exception.dart';
import 'message_senders.dart';
import 'password_hasher.dart';

enum OtpPurpose { verifyEmail, twoFactor }

extension on OtpPurpose {
  String get db => this == OtpPurpose.verifyEmail ? 'VERIFY_EMAIL' : 'TWO_FACTOR';
}

/// Codes à 6 chiffres envoyés par email (EmailJS) pour vérifier l'email
/// à l'inscription et pour la double authentification.
/// Stockés hachés, valables 10 min, 5 essais, un envoi par minute.
class OtpService {
  static const validity = Duration(minutes: 10);
  static const resendDelay = Duration(seconds: 60);
  static const maxAttempts = 5;

  final DatabaseHelper _helper;
  final EmailJsSender _email;
  OtpService({DatabaseHelper? helper, EmailJsSender? email})
      : _helper = helper ?? DatabaseHelper.instance,
        _email = email ?? EmailJsSender();

  Future<void> send({
    required int userId,
    required String email,
    required String name,
    required OtpPurpose purpose,
    bool reuseRecent = false,
  }) async {
    final db = await _helper.database;
    final last = await db.query('verification_codes',
        where: 'user_id = ? AND purpose = ?',
        whereArgs: [userId, purpose.db],
        orderBy: 'created_at DESC',
        limit: 1);
    if (last.isNotEmpty) {
      final at = DateTime.parse(last.first['created_at'] as String);
      final wait = resendDelay - DateTime.now().difference(at);
      if (!wait.isNegative) {
        // Un code vient d'être envoyé et reste valable : on ne renvoie rien.
        if (reuseRecent && last.first['used'] == 0) return;
        throw AuthException(
            'Patiente ${wait.inSeconds + 1} s avant de demander un nouveau code.');
      }
    }
    final code = (Random.secure().nextInt(900000) + 100000).toString();
    final now = DateTime.now();
    await db.update('verification_codes', {'used': 1},
        where: 'user_id = ? AND purpose = ? AND used = 0',
        whereArgs: [userId, purpose.db]);
    final id = await db.insert('verification_codes', {
      'user_id': userId,
      'purpose': purpose.db,
      'code_hash': PasswordHasher.hashAnswer(code),
      'expires_at': now.add(validity).toIso8601String(),
      'created_at': now.toIso8601String(),
    });
    try {
      await _email.sendResetCode(toEmail: email, toName: name, code: code);
    } catch (_) {
      await db.delete('verification_codes', where: 'id = ?', whereArgs: [id]);
      rethrow;
    }
  }

  /// Vérifie le code ; lève une AuthException s'il est faux ou expiré.
  Future<void> verify({
    required int userId,
    required OtpPurpose purpose,
    required String code,
  }) async {
    final db = await _helper.database;
    final rows = await db.query('verification_codes',
        where: 'user_id = ? AND purpose = ? AND used = 0',
        whereArgs: [userId, purpose.db],
        orderBy: 'created_at DESC',
        limit: 1);
    if (rows.isEmpty) {
      throw const AuthException('Aucun code en cours. Demande un nouveau code.');
    }
    final r = rows.first;
    final id = r['id'] as int;
    if (DateTime.now().isAfter(DateTime.parse(r['expires_at'] as String))) {
      await db.update('verification_codes', {'used': 1},
          where: 'id = ?', whereArgs: [id]);
      throw const AuthException('Ce code a expiré. Demande un nouveau code.');
    }
    final attempts = (r['attempts'] as int) + 1;
    if (!PasswordHasher.verifyAnswer(code.trim(), r['code_hash'] as String)) {
      final blocked = attempts >= maxAttempts;
      await db.update('verification_codes',
          {'attempts': attempts, 'used': blocked ? 1 : 0},
          where: 'id = ?', whereArgs: [id]);
      throw AuthException(blocked
          ? 'Trop d\'essais. Demande un nouveau code.'
          : 'Code incorrect (${maxAttempts - attempts} essai(s) restant(s)).');
    }
    await db.update('verification_codes', {'used': 1},
        where: 'id = ?', whereArgs: [id]);
  }
}
