import '../dao/activity_log_dao.dart';
import '../dao/delivery_agent_dao.dart';
import '../dao/preference_dao.dart';
import '../dao/user_dao.dart';
import '../models/activity_log.dart';
import '../models/delivery_agent.dart';
import '../models/preference.dart';
import '../models/user.dart';
import 'auth_exception.dart';
import 'message_senders.dart';
import 'password_hasher.dart';

/// Actions réservées à l'Administrateur (création de comptes, rôles, statut).
/// Chaque action est tracée dans le journal d'activité.
class AdminService {
  final UserDao _users;
  final DeliveryAgentDao _agents;
  final PreferenceDao _prefs;
  final ActivityLogDao _logs;

  AdminService({
    UserDao? users,
    DeliveryAgentDao? agents,
    PreferenceDao? prefs,
    ActivityLogDao? logs,
  })  : _users = users ?? UserDao(),
        _agents = agents ?? DeliveryAgentDao(),
        _prefs = prefs ?? PreferenceDao(),
        _logs = logs ?? ActivityLogDao();

  Future<User> createUser({
    required int adminId,
    required String nom,
    required String prenom,
    required String email,
    String? telephone,
    required UserRole role,
    required String password,
    String? typeVehicule,
  }) async {
    final mail = email.trim().toLowerCase();
    if (await _users.emailExists(mail)) {
      throw const AuthException('Un compte existe déjà avec cet email');
    }
    final err = PasswordHasher.validate(password);
    if (err != null) throw AuthException(err);

    final salt = PasswordHasher.generateSalt();
    final id = await _users.insert(
      User(
        nom: nom.trim(),
        prenom: prenom.trim(),
        email: mail,
        telephone: telephone?.trim(),
        role: role,
        dateCreation: DateTime.now(),
      ),
      passwordHash: PasswordHasher.hash(password, salt),
      salt: salt,
    );
    await _prefs.save(Preference(userId: id));
    if (role == UserRole.livreur) {
      await _agents.save(DeliveryAgent(userId: id, typeVehicule: typeVehicule));
    }
    await _logs.log(adminId, LogAction.createUser, '${role.label} : $mail');
    return (await _users.getById(id))!;
  }

  Future<void> changeRole(int adminId, User target, UserRole newRole) async {
    if (target.id == adminId) {
      throw const AuthException('Vous ne pouvez pas modifier votre propre rôle');
    }
    if (target.role == UserRole.admin && await _users.countAdmins() <= 1) {
      throw const AuthException('Il doit rester au moins un administrateur');
    }
    await _users.updateRole(target.id!, newRole);
    if (newRole == UserRole.livreur) {
      await _agents.save(await _agents.getProfile(target.id!));
    }
    await _logs.log(adminId, LogAction.changeRole,
        '${target.email} : ${target.role.label} → ${newRole.label}');
  }

  /// Active / désactive un compte puis prévient l'utilisateur par email.
  /// Le changement de statut est fait même si l'email échoue ; le texte
  /// retourné indique ce qu'il en est de l'email.
  Future<String> setBlocked(int adminId, User target, bool blocked) async {
    if (target.id == adminId) {
      throw const AuthException('Vous ne pouvez pas désactiver votre propre compte');
    }
    await _users.updateStatus(
        target.id!, blocked ? UserStatus.bloque : UserStatus.actif);
    await _logs.log(adminId,
        blocked ? LogAction.blockUser : LogAction.unblockUser, target.email);
    try {
      await EmailJsSender().sendAccountStatus(
        toEmail: target.email,
        toName: target.prenom,
        active: !blocked,
        roleLabel: target.role.label,
      );
      return 'email envoyé à ${target.email}';
    } on AuthException catch (e) {
      return 'email non envoyé (${e.message})';
    }
  }

  Future<void> deleteUser(int adminId, User target) async {
    if (target.id == adminId) {
      throw const AuthException('Vous ne pouvez pas supprimer votre propre compte');
    }
    if (target.role == UserRole.admin && await _users.countAdmins() <= 1) {
      throw const AuthException('Il doit rester au moins un administrateur');
    }
    await _users.delete(target.id!);
    await _logs.log(adminId, LogAction.deleteUser, target.email);
  }

  /// Email groupé à tous les comptes actifs d'un rôle (ou à tous si null).
  /// Un envoi par seconde (limite d'EmailJS). [onProgress] : (envoyés, total).
  Future<({int sent, int failed})> sendBulkEmail({
    required int adminId,
    required UserRole? role,
    required String subject,
    required String message,
    void Function(int done, int total)? onProgress,
  }) async {
    final targets = await _users.getActiveByRole(role);
    if (targets.isEmpty) {
      throw const AuthException('Aucun destinataire actif pour ce groupe');
    }
    final mail = EmailJsSender();
    var sent = 0, failed = 0;
    for (var i = 0; i < targets.length; i++) {
      final u = targets[i];
      try {
        await mail.sendNotice(
            toEmail: u.email, toName: u.prenom, subject: subject, title: subject, message: message);
        sent++;
      } on AuthException catch (e) {
        // Configuration manquante : inutile de continuer.
        if (e.message.contains('non configuré')) rethrow;
        failed++;
      }
      onProgress?.call(i + 1, targets.length);
      if (i < targets.length - 1) await Future.delayed(const Duration(milliseconds: 1100));
    }
    await _logs.log(adminId, LogAction.bulkEmail,
        '${role?.label ?? 'Tous'} : $sent envoyé(s), $failed échec(s) — $subject');
    return (sent: sent, failed: failed);
  }

  /// Inscriptions des 6 derniers mois (graphique).
  Future<Map<String, int>> signupsByMonth() => _users.countByMonth(6);

  /// Données du tableau de bord.
  Future<AdminDashboardData> dashboard() async {
    final now = DateTime.now();
    return AdminDashboardData(
      parRole: await _users.countByRole(),
      bloques: await _users.countBlocked(),
      nouveaux7j: await _users.countCreatedSince(now.subtract(const Duration(days: 7))),
      derniersLogs: await _logs.getAll(limit: 5),
      parMois: await _users.countByMonth(6),
    );
  }
}

class AdminDashboardData {
  final Map<String, int> parRole;
  final int bloques;
  final int nouveaux7j;
  final List<ActivityLog> derniersLogs;
  final Map<String, int> parMois; // « 2026-10 » → inscriptions

  const AdminDashboardData({
    required this.parMois,
    required this.parRole,
    required this.bloques,
    required this.nouveaux7j,
    required this.derniersLogs,
  });

  int get total => parRole.values.fold(0, (a, b) => a + b);
  int count(UserRole r) => parRole[r.db] ?? 0;
}
