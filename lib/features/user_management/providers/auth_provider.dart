import 'dart:async';

import 'package:flutter/widgets.dart';

import '../dao/activity_log_dao.dart';
import '../dao/user_dao.dart';
import '../models/user.dart';
import '../models/activity_log.dart';
import '../services/auth_exception.dart';
import '../services/auth_service.dart';
import '../services/biometric_service.dart';
import '../services/google_auth_service.dart';
import '../services/otp_service.dart';

/// État global de l'utilisateur connecté (à exposer via ChangeNotifierProvider
/// à la racine de l'app : les autres modules lisent `currentUser` d'ici).
class AuthProvider extends ChangeNotifier {
  final AuthService _auth;
  final UserDao _users;

  final BiometricService _bio;
  final GoogleAuthService _google;

  AuthProvider({
    AuthService? auth,
    UserDao? users,
    BiometricService? bio,
    GoogleAuthService? google,
  })  : _auth = auth ?? AuthService(),
        _users = users ?? UserDao(),
        _bio = bio ?? BiometricService(),
        _google = google ?? GoogleAuthService();

  User? _user;
  bool _initialized = false;

  User? get currentUser => _user;
  bool get isLoggedIn => _user != null;
  bool get initialized => _initialized;
  UserRole? get role => _user?.role;

  // ───────── Déconnexion automatique après inactivité ─────────
  static const inactivityTimeout = Duration(minutes: 30);

  /// Clé du Navigator (MaterialApp.navigatorKey) pour fermer les écrans
  /// ouverts lors d'une déconnexion automatique.
  static final navigatorKey = GlobalKey<NavigatorState>();
  Timer? _idleTimer;
  DateTime _lastActivity = DateTime.now();
  bool _sessionExpired = false;

  /// Appelé à chaque toucher de l'écran (voir InactivityGuard).
  void touch() {
    if (_user == null) return;
    _lastActivity = DateTime.now();
    _idleTimer?.cancel();
    _idleTimer = Timer(inactivityTimeout, _expire);
  }

  /// Au retour de l'app au premier plan : la minuterie a pu être suspendue.
  void checkInactivity() {
    if (_user != null && DateTime.now().difference(_lastActivity) >= inactivityTimeout) {
      _expire();
    } else {
      touch();
    }
  }

  Future<void> _expire() async {
    if (_user == null) return;
    await ActivityLogDao().log(_user!.id, LogAction.sessionExpired);
    _sessionExpired = true;
    navigatorKey.currentState?.popUntil((r) => r.isFirst);
    await logout();
  }

  /// Vrai une seule fois après une déconnexion automatique (message à afficher).
  bool consumeSessionExpired() {
    final v = _sessionExpired;
    _sessionExpired = false;
    return v;
  }

  void _setUser(User? u) {
    _user = u;
    if (u != null) touch();
    notifyListeners();
  }

  Future<void> init() async {
    _user = await _auth.restoreSession();
    _initialized = true;
    _setUser(_user);
  }

  /// Peut lever EmailNotVerifiedException ou TwoFactorRequiredException.
  Future<void> login(String email, String password) async {
    _setUser(await _auth.login(email, password));
  }

  Future<void> sendOtp(int userId, OtpPurpose purpose, {bool resend = false}) =>
      _auth.sendOtp(userId, purpose, resend: resend);

  Future<void> verifyEmail(int userId, String code) => _auth.verifyEmail(userId, code);

  Future<void> completeTwoFactor(int userId, String code) async {
    _setUser(await _auth.completeTwoFactor(userId, code));
  }

  /// Connexion par empreinte / visage (compte activé dans le profil).
  Future<void> loginWithBiometric() async {
    final id = await _bio.enrolledUserId();
    if (id == null) {
      throw const AuthException(
          'Connecte-toi une première fois, puis active la biométrie dans ton profil.');
    }
    if (!await _bio.authenticate('Connecte-toi à Bnin')) return;
    try {
      _setUser(await _auth.loginTrusted(id, LogAction.biometricLogin));
    } on AuthException {
      await _bio.disable(); // compte supprimé ou bloqué
      rethrow;
    }
  }

  /// Connexion avec Google (crée un compte client si nécessaire).
  Future<void> loginWithGoogle() async {
    final g = await _google.signIn();
    if (g == null) return; // fenêtre fermée
    _setUser(await _auth.loginWithGoogleProfile(email: g.email, displayName: g.name));
  }

  /// Crée le compte. L'écran enchaîne ensuite selon le résultat :
  /// vérification de l'email, attente de validation admin, ou connexion.
  Future<({int userId, bool needsVerification, bool pending})> register({
    String? referralCode,
    String? permisPhotoPath,
    UserRole role = UserRole.client,
    String? typeVehicule,
    required String nom,
    required String prenom,
    required String email,
    String? telephone,
    required String password,
    required String securityQuestion,
    required String securityAnswer,
    String? addressLabel,
    String? street,
    String? city,
    double? latitude,
    double? longitude,
  }) async {
    final created = await _auth.register(
      role: role,
      typeVehicule: typeVehicule,
      nom: nom,
      prenom: prenom,
      email: email,
      telephone: telephone,
      password: password,
      securityQuestion: securityQuestion,
      securityAnswer: securityAnswer,
      addressLabel: addressLabel,
      street: street,
      city: city,
      latitude: latitude,
      longitude: longitude,
      referralCode: referralCode,
      permisPhotoPath: permisPhotoPath,
    );
    final needsVerification = await _users.needsEmailVerification(created.id!);
    if (!needsVerification && !created.estBloque) await login(email, password);
    return (
      userId: created.id!,
      needsVerification: needsVerification,
      pending: created.estBloque,
    );
  }

  Future<void> logout() async {
    _idleTimer?.cancel();
    await _google.signOut();
    await _auth.logout(_user?.id);
    _user = null;
    notifyListeners();
  }

  /// À appeler après une modification du profil.
  Future<void> refresh() async {
    if (_user?.id == null) return;
    _user = await _users.getById(_user!.id!);
    notifyListeners();
  }

  void setUser(User u) => _setUser(u);

  /// Après suppression du compte.
  Future<void> clearAfterDeletion() async {
    _idleTimer?.cancel();
    if (_user?.id != null) await _bio.disableIfUser(_user!.id!);
    await _google.signOut();
    await _auth.logout(null);
    _user = null;
    notifyListeners();
  }
}
