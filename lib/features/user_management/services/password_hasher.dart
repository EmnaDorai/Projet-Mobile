import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Hachage SHA-256 salé (suffisant pour un projet académique local).
class PasswordHasher {
  static String generateSalt([int length = 16]) {
    final r = Random.secure();
    return base64Url.encode(List<int>.generate(length, (_) => r.nextInt(256)));
  }

  static String hash(String value, String salt) =>
      sha256.convert(utf8.encode('$salt:$value')).toString();

  static bool verify(String value, String salt, String expectedHash) =>
      hash(value, salt) == expectedHash;

  /// Règle : 8 caractères min., une majuscule, un chiffre.
  static String? validate(String? pwd) {
    if (pwd == null || pwd.length < 8) return '8 caractères minimum';
    if (!pwd.contains(RegExp(r'[A-Z]'))) return 'Au moins une majuscule';
    if (!pwd.contains(RegExp(r'[0-9]'))) return 'Au moins un chiffre';
    return null;
  }

  /// Réponse de sécurité : normalisée puis hachée avec son PROPRE sel,
  /// stocké sous la forme "sel\$hash" (indépendant du mot de passe).
  static String hashAnswer(String answer) {
    final salt = generateSalt();
    return '$salt\$${hash(_normalize(answer), salt)}';
  }

  static bool verifyAnswer(String answer, String? stored) {
    if (stored == null || !stored.contains(r'$')) return false;
    final i = stored.indexOf(r'$');
    return hash(_normalize(answer), stored.substring(0, i)) ==
        stored.substring(i + 1);
  }

  static String _normalize(String a) => a.trim().toLowerCase();
}
