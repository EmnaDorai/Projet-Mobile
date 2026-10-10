import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

import '../../../core/config/api_config.dart';
import '../dao/activity_log_dao.dart';
import '../dao/address_dao.dart';
import '../dao/delivery_agent_dao.dart';
import '../dao/preference_dao.dart';
import '../dao/user_dao.dart';
import '../models/activity_log.dart';
import '../models/address.dart';
import '../models/delivery_agent.dart';
import '../models/preference.dart';
import '../models/user.dart';
import 'auth_exception.dart';
import 'device_info_service.dart';
import 'otp_service.dart';
import 'password_hasher.dart';
import 'session_service.dart';

/// Inscription, connexion, session et mots de passe.
/// Sans serveur, le « mot de passe oublié » passe par une question de sécurité.
class AuthService {
  final UserDao _users;
  final PreferenceDao _prefs;
  final ActivityLogDao _logs;
  final SessionService _session;
  final OtpService _otp;

  AuthService({
    UserDao? users,
    PreferenceDao? prefs,
    ActivityLogDao? logs,
    SessionService? session,
    OtpService? otp,
  })  : _users = users ?? UserDao(),
        _prefs = prefs ?? PreferenceDao(),
        _logs = logs ?? ActivityLogDao(),
        _session = session ?? SessionService(),
        _otp = otp ?? OtpService();

  /// Verrouillage après trop d'échecs de connexion.
  static const maxFailedLogins = 5;
  static const lockDuration = Duration(minutes: 15);

  /// Points de parrainage.
  static const referrerBonus = 50;
  static const refereeBonus = 20;

  static const securityQuestions = [
    'Quel est le nom de votre premier animal ?',
    'Dans quelle ville êtes-vous né(e) ?',
    'Quel est votre plat préféré ?',
    'Quel est le prénom de votre meilleur(e) ami(e) d\'enfance ?',
  ];

  /// Rôles qu'on peut choisir soi-même à l'inscription (jamais Admin).
  static const selfRegisterRoles = [UserRole.client, UserRole.livreur, UserRole.manager];

  /// Inscription. Un client est actif tout de suite ; un compte Livreur ou
  /// Manager est créé « en attente » (statut BLOQUE) jusqu'à ce que
  /// l'administrateur le valide depuis la liste des utilisateurs.
  Future<User> register({
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
    String? referralCode,
    String? permisPhotoPath,
  }) async {
    final mail = email.trim().toLowerCase();
    if (await _users.emailExists(mail)) {
      throw const AuthException('Un compte existe déjà avec cet email');
    }
    int? parrainId;
    if ((referralCode ?? '').trim().isNotEmpty) {
      parrainId = await _users.findIdByReferralCode(referralCode!);
      if (parrainId == null) {
        throw const AuthException('Code de parrainage introuvable');
      }
    }
    if (!selfRegisterRoles.contains(role)) {
      throw const AuthException('Ce rôle ne peut pas être choisi à l\'inscription');
    }
    final pwdError = PasswordHasher.validate(password);
    if (pwdError != null) throw AuthException(pwdError);

    final salt = PasswordHasher.generateSalt();
    final user = User(
      nom: nom.trim(),
      prenom: prenom.trim(),
      email: mail,
      telephone: telephone?.trim(),
      role: role,
      statut: role == UserRole.client ? UserStatus.actif : UserStatus.bloque,
      questionSecurite: securityQuestion,
      dateCreation: DateTime.now(),
    );
    final id = await _users.insert(
      user,
      passwordHash: PasswordHasher.hash(password, salt),
      salt: salt,
      securityAnswerHash: PasswordHasher.hashAnswer(securityAnswer),
      // Sans EmailJS configuré, impossible d'envoyer le code : compte vérifié.
      emailVerified: !ApiConfig.emailJsConfigured,
    );
    await _prefs.save(Preference(userId: id));
    await _users.setReferral(id, code: _newReferralCode(id), parrainId: parrainId);
    if (parrainId != null) {
      await _users.addBonusPoints(parrainId, referrerBonus);
      await _users.addBonusPoints(id, refereeBonus);
      await _logs.log(parrainId, LogAction.referral, 'Filleul : $mail (+$referrerBonus pts)');
    }
    if (role == UserRole.livreur) {
      String? permis;
      if (permisPhotoPath != null) {
        // Copie dans le dossier de l'app (le cache peut être vidé).
        final dir = await getApplicationDocumentsDirectory();
        permis = '${dir.path}/permis_$id.jpg';
        await File(permisPhotoPath).copy(permis);
      }
      await DeliveryAgentDao().save(
          DeliveryAgent(userId: id, typeVehicule: typeVehicule, permisPhoto: permis));
    }
    // Adresse de livraison (clients) → adresse par défaut.
    if (role == UserRole.client &&
        (street ?? '').trim().isNotEmpty && (city ?? '').trim().isNotEmpty) {
      await AddressDao().insert(Address(
        userId: id,
        libelle: (addressLabel ?? '').trim().isEmpty ? 'Maison' : addressLabel!.trim(),
        rue: street!.trim(),
        ville: city!.trim(),
        latitude: latitude,
        longitude: longitude,
        parDefaut: true,
      ));
    }
    await _logs.log(id, LogAction.register,
        role == UserRole.client ? null : '${role.label} — en attente de validation');
    return (await _users.getById(id))!;
  }

  Future<User> login(String email, String password) async {
    final row = await _users.getCredentialsByEmail(email);
    if (row == null) {
      throw const AuthException('Email ou mot de passe incorrect');
    }
    final id = row['id'] as int;

    // 1. Compte verrouillé après trop d'échecs ?
    final lockedUntil = DateTime.tryParse(row['verrouille_jusqua'] as String? ?? '');
    if (lockedUntil != null && lockedUntil.isAfter(DateTime.now())) {
      final min = lockedUntil.difference(DateTime.now()).inMinutes + 1;
      throw AuthException('Compte verrouillé après $maxFailedLogins échecs. '
          'Réessaie dans $min min ou utilise « Mot de passe oublié ».');
    }

    // 2. Mot de passe
    if (!_checkPassword(row, password)) {
      final n = await _users.addFailedLogin(id);
      await _logs.log(id, LogAction.loginFailed, await DeviceInfoService.describe());
      if (n >= maxFailedLogins) {
        await _users.lockUntil(id, DateTime.now().add(lockDuration));
        await _logs.log(id, LogAction.accountLocked);
        throw AuthException('$maxFailedLogins échecs : compte verrouillé pendant '
            '${lockDuration.inMinutes} minutes.');
      }
      throw AuthException('Email ou mot de passe incorrect '
          '(${maxFailedLogins - n} essai(s) restant(s)).');
    }
    await _users.clearFailedLogins(id);
    final user = User.fromMap(row);

    // 3. Email vérifié ?
    if ((row['email_verifie'] as int? ?? 1) == 0) {
      throw EmailNotVerifiedException(id, user.email);
    }
    // 4. Compte actif ?
    if (user.estBloque) {
      throw const AuthException(
          'Compte bloqué ou en attente de validation par l\'administrateur.');
    }
    // 5. Double authentification : code par email avant d'ouvrir la session.
    if ((row['double_auth'] as int? ?? 0) == 1) {
      await _otp.send(
          userId: id,
          email: user.email,
          name: user.prenom,
          purpose: OtpPurpose.twoFactor,
          reuseRecent: true);
      throw TwoFactorRequiredException(id, user.email);
    }
    await _session.save(id, user.role.db);
    await _logs.log(id, LogAction.login, await DeviceInfoService.describe());
    return user;
  }

  // ───────── Codes par email (vérification + double authentification) ─────────
  Future<void> sendOtp(int userId, OtpPurpose purpose, {bool resend = false}) async {
    final user = await _users.getById(userId);
    if (user == null) throw const AuthException('Ce compte n\'existe plus.');
    await _otp.send(
        userId: userId,
        email: user.email,
        name: user.prenom,
        purpose: purpose,
        reuseRecent: !resend);
  }

  Future<void> verifyEmail(int userId, String code) async {
    await _otp.verify(userId: userId, purpose: OtpPurpose.verifyEmail, code: code);
    await _users.setEmailVerified(userId);
    await _logs.log(userId, LogAction.emailVerified);
  }

  /// Fin de la connexion en 2 étapes : code correct → session ouverte.
  Future<User> completeTwoFactor(int userId, String code) async {
    await _otp.verify(userId: userId, purpose: OtpPurpose.twoFactor, code: code);
    return loginTrusted(userId, LogAction.twoFactorLogin);
  }

  Future<bool> isTwoFactorEnabled(int userId) => _users.isTwoFactorEnabled(userId);

  /// Activer exige le code reçu par email (prouve que l'email fonctionne,
  /// pour ne pas se bloquer dehors). Désactiver exige le mot de passe.
  Future<void> enableTwoFactor(int userId, String code) async {
    await _otp.verify(userId: userId, purpose: OtpPurpose.twoFactor, code: code);
    await _users.setTwoFactor(userId, true);
    await _logs.log(userId, LogAction.twoFactorSetting, 'Activée');
  }

  Future<void> disableTwoFactor(int userId, String password) async {
    final row = await _users.getCredentialsById(userId);
    if (row == null || !_checkPassword(row, password)) {
      throw const AuthException('Mot de passe incorrect');
    }
    await _users.setTwoFactor(userId, false);
    await _logs.log(userId, LogAction.twoFactorSetting, 'Désactivée');
  }

  /// Suppression du compte par l'utilisateur lui-même (droit à l'effacement).
  Future<void> deleteOwnAccount(int userId, String password) async {
    final row = await _users.getCredentialsById(userId);
    if (row == null || !_checkPassword(row, password)) {
      throw const AuthException('Mot de passe incorrect');
    }
    if (row['role'] == 'ADMIN' && await _users.countAdmins() <= 1) {
      throw const AuthException('Il doit rester au moins un administrateur');
    }
    await _logs.log(userId, LogAction.deleteOwnAccount, row['email'] as String);
    await _users.delete(userId);
    await _session.clear();
  }

  static String _newReferralCode(int id) {
    const letters = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    final r = Random.secure();
    return 'BNIN$id${letters[r.nextInt(letters.length)]}${letters[r.nextInt(letters.length)]}';
  }

  /// Restaure la session au démarrage (null si aucune, ou compte bloqué/supprimé).
  Future<User?> restoreSession() async {
    final id = await _session.currentUserId();
    if (id == null) return null;
    final user = await _users.getById(id);
    if (user == null || user.estBloque) {
      await _session.clear();
      return null;
    }
    return user;
  }

  Future<void> logout(int? userId) async {
    await _logs.log(userId, LogAction.logout);
    await _session.clear();
  }

  /// « Mot de passe oublié » — étape 1 : récupérer la question.
  Future<String> getSecurityQuestion(String email) async {
    final row = await _users.getCredentialsByEmail(email);
    final q = row?['question_securite'] as String?;
    if (row == null || q == null || q.isEmpty || row['reponse_securite'] == null) {
      throw const AuthException(
          'Aucune question de sécurité pour ce compte. Contactez l\'administrateur.');
    }
    return q;
  }

  /// « Mot de passe oublié » — étape 2 : vérifier la réponse puis changer.
  Future<void> resetPasswordWithSecurityAnswer({
    required String email,
    required String answer,
    required String newPassword,
  }) async {
    final row = await _users.getCredentialsByEmail(email);
    if (row == null ||
        !PasswordHasher.verifyAnswer(answer, row['reponse_securite'] as String?)) {
      throw const AuthException('Réponse incorrecte');
    }
    await _setPassword(row['id'] as int, newPassword);
    await _logs.log(row['id'] as int, LogAction.resetPassword);
  }

  Future<void> changePassword(
      int userId, String oldPassword, String newPassword) async {
    final row = await _users.getCredentialsById(userId);
    if (row == null || !_checkPassword(row, oldPassword)) {
      throw const AuthException('Mot de passe actuel incorrect');
    }
    await _setPassword(userId, newPassword);
    await _logs.log(userId, LogAction.changePassword);
  }

  /// Réinitialisation par l'Admin (aucune vérification de l'ancien mot de passe).
  Future<void> adminResetPassword(int adminId, int userId, String newPassword) async {
    await _setPassword(userId, newPassword);
    await _logs.log(adminId, LogAction.resetPassword, 'Utilisateur #$userId');
  }

  Future<void> setSecurityQuestion(
      int userId, String password, String question, String answer) async {
    final row = await _users.getCredentialsById(userId);
    if (row == null || !_checkPassword(row, password)) {
      throw const AuthException('Mot de passe incorrect');
    }
    await _users.updateSecurity(userId, question, PasswordHasher.hashAnswer(answer));
  }

  /// Nouveau mot de passe après vérification d'un code (email / SMS).
  Future<void> forceSetPassword(int userId, String newPassword) async {
    await _setPassword(userId, newPassword);
    await _users.clearFailedLogins(userId); // déverrouille le compte
  }

  /// Connexion sans mot de passe, une fois l'identité vérifiée autrement
  /// (biométrie du téléphone ou compte Google).
  Future<User> loginTrusted(int userId, String action, [String? details]) async {
    final user = await _users.getById(userId);
    if (user == null) {
      throw const AuthException('Ce compte n\'existe plus.');
    }
    if (user.estBloque) {
      throw const AuthException(
          'Compte bloqué ou en attente de validation par l\'administrateur.');
    }
    await _session.save(user.id!, user.role.db);
    await _logs.log(user.id, action, details ?? await DeviceInfoService.describe());
    return user;
  }

  /// Connexion Google : ouvre le compte existant (même email) ou crée un
  /// compte client. Un mot de passe aléatoire est attribué ; l'utilisateur
  /// peut en définir un via « Mot de passe oublié ».
  Future<User> loginWithGoogleProfile({
    required String email,
    String? displayName,
  }) async {
    final mail = email.trim().toLowerCase();
    final row = await _users.getCredentialsByEmail(mail);
    final int id;
    if (row != null) {
      id = row['id'] as int;
      // Google a déjà vérifié l'adresse email.
      await _users.setEmailVerified(id);
    } else {
      final parts = (displayName ?? '').trim().split(RegExp(r'\s+'));
      final prenom = parts.first.isNotEmpty ? parts.first : mail.split('@').first;
      final nom = parts.length > 1 ? parts.sublist(1).join(' ') : '-';
      final salt = PasswordHasher.generateSalt();
      id = await _users.insert(
        User(
          nom: nom,
          prenom: prenom,
          email: mail,
          role: UserRole.client,
          dateCreation: DateTime.now(),
        ),
        passwordHash: PasswordHasher.hash(PasswordHasher.generateSalt(32), salt),
        salt: salt,
      );
      await _prefs.save(Preference(userId: id));
      await _users.setReferral(id, code: _newReferralCode(id));
      await _logs.log(id, LogAction.register, 'Via Google');
    }
    return loginTrusted(id, LogAction.googleLogin);
  }

  bool _checkPassword(Map<String, Object?> row, String password) =>
      PasswordHasher.verify(
          password, row['sel'] as String, row['mot_de_passe'] as String);

  Future<void> _setPassword(int userId, String newPassword) async {
    final err = PasswordHasher.validate(newPassword);
    if (err != null) throw AuthException(err);
    final salt = PasswordHasher.generateSalt();
    await _users.updatePassword(
        userId, PasswordHasher.hash(newPassword, salt), salt);
  }
}
