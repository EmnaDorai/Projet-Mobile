import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../models/user.dart';

/// Accès à la table users. Les colonnes sensibles (mot_de_passe, sel,
/// reponse_securite) ne sont manipulées que par AuthService.
class UserDao {
  final DatabaseHelper _helper;
  UserDao([DatabaseHelper? helper]) : _helper = helper ?? DatabaseHelper.instance;

  static const _publicColumns = [
    'id', 'nom', 'prenom', 'email', 'telephone', 'photo', 'role', 'statut',
    'question_securite', 'date_creation',
  ];

  Future<Database> get _db => _helper.database;

  Future<int> insert(User user,
      {required String passwordHash,
      required String salt,
      String? securityAnswerHash,
      bool emailVerified = true}) async {
    final db = await _db;
    return db.insert('users', {
      ...user.toMap()..remove('id'),
      'mot_de_passe': passwordHash,
      'sel': salt,
      'reponse_securite': securityAnswerHash,
      'email_verifie': emailVerified ? 1 : 0,
    });
  }

  // ───────── Sécurité de connexion ─────────
  Future<void> setEmailVerified(int id) async {
    final db = await _db;
    await db.update('users', {'email_verifie': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> needsEmailVerification(int id) async {
    final db = await _db;
    return (Sqflite.firstIntValue(await db
                .rawQuery('SELECT email_verifie FROM users WHERE id = ?', [id])) ??
            1) ==
        0;
  }

  /// +1 échec ; retourne le nouveau nombre d'échecs.
  Future<int> addFailedLogin(int id) async {
    final db = await _db;
    await db.rawUpdate(
        'UPDATE users SET echecs_connexion = echecs_connexion + 1 WHERE id = ?', [id]);
    return Sqflite.firstIntValue(await db.rawQuery(
            'SELECT echecs_connexion FROM users WHERE id = ?', [id])) ??
        0;
  }

  Future<void> lockUntil(int id, DateTime until) async {
    final db = await _db;
    await db.update('users',
        {'verrouille_jusqua': until.toIso8601String(), 'echecs_connexion': 0},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearFailedLogins(int id) async {
    final db = await _db;
    await db.update('users', {'echecs_connexion': 0, 'verrouille_jusqua': null},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setTwoFactor(int id, bool enabled) async {
    final db = await _db;
    await db.update('users', {'double_auth': enabled ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> isTwoFactorEnabled(int id) async {
    final db = await _db;
    return (Sqflite.firstIntValue(await db
                .rawQuery('SELECT double_auth FROM users WHERE id = ?', [id])) ??
            0) ==
        1;
  }

  // ───────── Fidélité et parrainage ─────────
  Future<void> setReferral(int id, {required String code, int? parrainId}) async {
    final db = await _db;
    await db.update('users', {'code_parrainage': code, 'parraine_par': parrainId},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int?> findIdByReferralCode(String code) async {
    final db = await _db;
    final r = await db.query('users',
        columns: ['id'],
        where: 'code_parrainage = ?',
        whereArgs: [code.trim().toUpperCase()]);
    return r.isEmpty ? null : r.first['id'] as int;
  }

  Future<void> addBonusPoints(int id, int points) async {
    final db = await _db;
    await db.rawUpdate(
        'UPDATE users SET points_bonus = points_bonus + ? WHERE id = ?', [points, id]);
  }

  /// Points bonus, code de parrainage et nombre de filleuls.
  Future<({int bonus, String? code, int filleuls})> referralInfo(int id) async {
    final db = await _db;
    final r = await db.query('users',
        columns: ['points_bonus', 'code_parrainage'], where: 'id = ?', whereArgs: [id]);
    final n = Sqflite.firstIntValue(await db
            .rawQuery('SELECT COUNT(*) FROM users WHERE parraine_par = ?', [id])) ??
        0;
    if (r.isEmpty) return (bonus: 0, code: null, filleuls: 0);
    return (
      bonus: r.first['points_bonus'] as int? ?? 0,
      code: r.first['code_parrainage'] as String?,
      filleuls: n,
    );
  }

  /// Nombre d'inscriptions par mois sur les [months] derniers mois (« 2026-10 » → n).
  Future<Map<String, int>> countByMonth(int months) async {
    final db = await _db;
    final now = DateTime.now();
    final from = DateTime(now.year, now.month - months + 1, 1);
    final r = await db.rawQuery('''
      SELECT substr(date_creation, 1, 7) AS mois, COUNT(*) AS n
      FROM users WHERE date_creation >= ?
      GROUP BY mois ORDER BY mois''', [from.toIso8601String()]);
    return {for (final row in r) row['mois'] as String: row['n'] as int};
  }

  /// Emails des comptes actifs d'un rôle (email groupé de l'admin).
  Future<List<User>> getActiveByRole(UserRole? role) async {
    final db = await _db;
    final r = await db.query('users',
        columns: _publicColumns,
        where: role == null ? "statut = 'ACTIF'" : "statut = 'ACTIF' AND role = ?",
        whereArgs: role == null ? null : [role.db]);
    return r.map(User.fromMap).toList();
  }

  Future<User?> getById(int id) async {
    final db = await _db;
    final r = await db.query('users',
        columns: _publicColumns, where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : User.fromMap(r.first);
  }

  Future<bool> emailExists(String email, {int? excludeId}) async {
    final db = await _db;
    final r = await db.query('users',
        columns: ['id'],
        where: excludeId == null ? 'email = ?' : 'email = ? AND id != ?',
        whereArgs: [email.trim().toLowerCase(), if (excludeId != null) excludeId]);
    return r.isNotEmpty;
  }

  /// Ligne complète (avec hash) — réservé à AuthService.
  Future<Map<String, Object?>?> getCredentialsByEmail(String email) async {
    final db = await _db;
    final r = await db.query('users',
        where: 'email = ?', whereArgs: [email.trim().toLowerCase()]);
    return r.isEmpty ? null : r.first;
  }

  Future<Map<String, Object?>?> getCredentialsById(int id) async {
    final db = await _db;
    final r = await db.query('users', where: 'id = ?', whereArgs: [id]);
    return r.isEmpty ? null : r.first;
  }

  /// Mise à jour du profil (sans toucher au rôle ni au statut).
  Future<int> updateProfile(User user) async {
    final db = await _db;
    return db.update(
      'users',
      {
        'nom': user.nom,
        'prenom': user.prenom,
        'email': user.email.trim().toLowerCase(),
        'telephone': user.telephone,
        'photo': user.photo,
      },
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<int> updatePassword(int id, String hash, String salt) async {
    final db = await _db;
    return db.update('users', {'mot_de_passe': hash, 'sel': salt},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateSecurity(int id, String question, String answerHash) async {
    final db = await _db;
    return db.update(
        'users', {'question_securite': question, 'reponse_securite': answerHash},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateRole(int id, UserRole role) async {
    final db = await _db;
    return db.update('users', {'role': role.db},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateStatus(int id, UserStatus statut) async {
    final db = await _db;
    return db.update('users', {'statut': statut.db},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> delete(int id) async {
    final db = await _db;
    return db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  /// Liste filtrée (Admin / Manager).
  Future<List<User>> getAll({
    UserRole? role,
    UserStatus? statut,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await _db;
    final where = <String>[];
    final args = <Object?>[];
    if (role != null) {
      where.add('role = ?');
      args.add(role.db);
    }
    if (statut != null) {
      where.add('statut = ?');
      args.add(statut.db);
    }
    if (search != null && search.trim().isNotEmpty) {
      where.add('(nom LIKE ? OR prenom LIKE ? OR email LIKE ? OR telephone LIKE ?)');
      final s = '%${search.trim()}%';
      args.addAll([s, s, s, s]);
    }
    final r = await db.query(
      'users',
      columns: _publicColumns,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'date_creation DESC',
      limit: limit,
      offset: offset,
    );
    return r.map(User.fromMap).toList();
  }

  /// Statistiques pour le tableau de bord Admin.
  Future<Map<String, int>> countByRole() async {
    final db = await _db;
    final r = await db.rawQuery('SELECT role, COUNT(*) AS n FROM users GROUP BY role');
    return {for (final row in r) row['role'] as String: row['n'] as int};
  }

  Future<int> countBlocked() async {
    final db = await _db;
    return Sqflite.firstIntValue(await db
            .rawQuery("SELECT COUNT(*) FROM users WHERE statut = 'BLOQUE'")) ??
        0;
  }

  Future<int> countCreatedSince(DateTime since) async {
    final db = await _db;
    return Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM users WHERE date_creation >= ?',
            [since.toIso8601String()])) ??
        0;
  }

  Future<int> countAdmins() async {
    final db = await _db;
    return Sqflite.firstIntValue(await db.rawQuery(
            "SELECT COUNT(*) FROM users WHERE role = 'ADMIN' AND statut = 'ACTIF'")) ??
        0;
  }
}
