import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_exception.dart';

/// Connexion avec un compte Google (API Google Sign-In).
/// Nécessite un ID client OAuth « Android » dans Google Cloud Console,
/// avec le nom de package com.example.restaurant_app et l'empreinte SHA-1.
class GoogleAuthService {
  final GoogleSignIn _google;
  GoogleAuthService({GoogleSignIn? google})
      : _google = google ?? GoogleSignIn(scopes: const ['email', 'profile']);

  /// null si l'utilisateur ferme la fenêtre.
  Future<({String email, String? name})?> signIn() async {
    try {
      // Force l'affichage du sélecteur de compte à chaque fois.
      await _google.signOut();
      final account = await _google.signIn();
      if (account == null) return null;
      return (email: account.email, name: account.displayName);
    } on PlatformException catch (e) {
      final msg = '${e.code} ${e.message ?? ''}';
      if (msg.contains('ApiException: 10') || msg.contains('DEVELOPER_ERROR')) {
        throw const AuthException(
            'Connexion Google non configurée : vérifie l\'ID client Android et l\'empreinte SHA-1.');
      }
      if (msg.contains('network_error') || msg.contains('ApiException: 7')) {
        throw const AuthException('Pas de connexion Internet.');
      }
      throw AuthException('Connexion Google impossible (${e.code}).');
    }
  }

  Future<void> signOut() async {
    try {
      await _google.signOut();
    } catch (_) {
      // Déjà déconnecté ou Google non configuré : rien à faire.
    }
  }
}
