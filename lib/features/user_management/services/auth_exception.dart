/// Erreur métier affichable directement à l'utilisateur.
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}

/// Mot de passe correct mais email pas encore vérifié : l'écran de
/// connexion ouvre l'écran de saisie du code.
class EmailNotVerifiedException extends AuthException {
  final int userId;
  final String email;
  const EmailNotVerifiedException(this.userId, this.email)
      : super('Vérifie ton email pour activer ton compte.');
}

/// Mot de passe correct, double authentification activée : un code a été
/// envoyé par email, il reste à le saisir.
class TwoFactorRequiredException extends AuthException {
  final int userId;
  final String email;
  const TwoFactorRequiredException(this.userId, this.email)
      : super('Un code de connexion a été envoyé par email.');
}
