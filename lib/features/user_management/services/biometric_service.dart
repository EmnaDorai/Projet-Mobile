import 'package:flutter/services.dart';
import 'package:local_auth/error_codes.dart' as codes;
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_exception.dart';

/// Connexion avec l'empreinte ou le visage enregistrés dans le téléphone.
/// L'app ne voit jamais les données biométriques : Android vérifie
/// l'identité et répond seulement « oui / non ».
class BiometricService {
  static const _kUserId = 'biometric_user_id';
  final LocalAuthentication _auth;

  BiometricService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  /// Le téléphone a un capteur ET au moins une empreinte/un visage enregistré.
  Future<bool> isAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      if (!await _auth.canCheckBiometrics) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException {
      return false;
    }
  }

  /// Ouvre la fenêtre système. true = identité confirmée, false = annulé.
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } on PlatformException catch (e) {
      throw AuthException(switch (e.code) {
        codes.notEnrolled =>
          'Aucune empreinte ni visage enregistré dans le téléphone.',
        codes.notAvailable => 'La biométrie n\'est pas disponible sur ce téléphone.',
        codes.lockedOut => 'Trop d\'essais. Réessaie dans 30 secondes.',
        codes.permanentlyLockedOut =>
          'Biométrie verrouillée. Déverrouille le téléphone avec ton code puis réessaie.',
        codes.passcodeNotSet =>
          'Définis d\'abord un code de verrouillage sur le téléphone.',
        _ => 'Vérification biométrique impossible (${e.code}).',
      });
    }
  }

  /// Compte associé à la biométrie sur ce téléphone (un seul à la fois).
  Future<int?> enrolledUserId() async =>
      (await SharedPreferences.getInstance()).getInt(_kUserId);

  Future<void> enable(int userId) async =>
      (await SharedPreferences.getInstance()).setInt(_kUserId, userId);

  Future<void> disable() async =>
      (await SharedPreferences.getInstance()).remove(_kUserId);

  Future<void> disableIfUser(int userId) async {
    if (await enrolledUserId() == userId) await disable();
  }
}
