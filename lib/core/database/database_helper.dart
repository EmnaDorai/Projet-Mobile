import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../features/user_management/services/password_hasher.dart';

/// Base SQLite PARTAGÉE par tout le groupe.
/// Chaque membre ajoute ses tables dans [_onCreate] (ou via une migration
/// dans [_onUpgrade]) — ne pas créer une deuxième base.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'restaurant.db';
  static const _dbVersion = 3;

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    _createUserManagementTables(batch);
    // TODO groupe : appeler ici la création des tables des autres modules
    // (_createMenuTables(batch), _createOrderTables(batch), ...)
    await batch.commit(noResult: true);
    await _migrateV3(db);
    await _seedAdmin(db);
  }

  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    // v2 : codes de réinitialisation envoyés par email / SMS
    if (oldV < 2) {
      final b = db.batch();
      _createPasswordResetsTable(b);
      await b.commit(noResult: true);
    }
    // v3 : sécurité (vérification email, verrouillage, 2FA), fidélité,
    // parrainage, documents et position des livreurs.
    if (oldV < 3) await _migrateV3(db);
  }

  Future<void> _migrateV3(Database db) async {
    final b = db.batch();
    // Les comptes existants sont considérés comme vérifiés.
    b.execute('ALTER TABLE users ADD COLUMN email_verifie INTEGER NOT NULL DEFAULT 1');
    b.execute('ALTER TABLE users ADD COLUMN echecs_connexion INTEGER NOT NULL DEFAULT 0');
    b.execute('ALTER TABLE users ADD COLUMN verrouille_jusqua TEXT');
    b.execute('ALTER TABLE users ADD COLUMN double_auth INTEGER NOT NULL DEFAULT 0');
    b.execute('ALTER TABLE users ADD COLUMN points_bonus INTEGER NOT NULL DEFAULT 0');
    b.execute('ALTER TABLE users ADD COLUMN code_parrainage TEXT');
    b.execute('ALTER TABLE users ADD COLUMN parraine_par INTEGER');
    b.execute('ALTER TABLE delivery_agents ADD COLUMN permis_photo TEXT');
    b.execute('ALTER TABLE delivery_agents ADD COLUMN latitude REAL');
    b.execute('ALTER TABLE delivery_agents ADD COLUMN longitude REAL');
    b.execute('ALTER TABLE delivery_agents ADD COLUMN position_maj TEXT');
    // Codes à usage unique : vérification d'email et double authentification.
    b.execute('''
      CREATE TABLE verification_codes (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id    INTEGER NOT NULL,
        purpose    TEXT NOT NULL CHECK (purpose IN ('VERIFY_EMAIL','TWO_FACTOR')),
        code_hash  TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        attempts   INTEGER NOT NULL DEFAULT 0,
        used       INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )''');
    await b.commit(noResult: true);
  }

  void _createPasswordResetsTable(Batch b) {
    b.execute('''
      CREATE TABLE password_resets (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id    INTEGER NOT NULL,
        code_hash  TEXT NOT NULL,
        channel    TEXT NOT NULL CHECK (channel IN ('EMAIL','SMS')),
        expires_at TEXT NOT NULL,
        attempts   INTEGER NOT NULL DEFAULT 0,
        used       INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )''');
  }

  // ───────────────────────── Module Gestion utilisateurs ─────────────────────────
  void _createUserManagementTables(Batch b) {
    b.execute('''
      CREATE TABLE users (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        nom               TEXT NOT NULL,
        prenom            TEXT NOT NULL,
        email             TEXT NOT NULL UNIQUE,
        telephone         TEXT,
        mot_de_passe      TEXT NOT NULL,
        sel               TEXT NOT NULL,
        photo             TEXT,
        role              TEXT NOT NULL CHECK (role IN ('CLIENT','ADMIN','MANAGER','LIVREUR')),
        statut            TEXT NOT NULL DEFAULT 'ACTIF' CHECK (statut IN ('ACTIF','BLOQUE')),
        question_securite TEXT,
        reponse_securite  TEXT,
        date_creation     TEXT NOT NULL
      )''');
    b.execute('''
      CREATE TABLE addresses (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id    INTEGER NOT NULL,
        libelle    TEXT NOT NULL,
        rue        TEXT NOT NULL,
        ville      TEXT NOT NULL,
        latitude   REAL,
        longitude  REAL,
        par_defaut INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )''');
    b.execute('''
      CREATE TABLE preferences (
        user_id       INTEGER PRIMARY KEY,
        allergies     TEXT,
        langue        TEXT NOT NULL DEFAULT 'fr',
        notifications INTEGER NOT NULL DEFAULT 1,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )''');
    b.execute('''
      CREATE TABLE delivery_agents (
        user_id       INTEGER PRIMARY KEY,
        type_vehicule TEXT,
        disponible    INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
      )''');
    b.execute('''
      CREATE TABLE activity_logs (
        id      INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        action  TEXT NOT NULL,
        details TEXT,
        date    TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
      )''');
    b.execute('CREATE INDEX idx_addresses_user ON addresses(user_id)');
    b.execute('CREATE INDEX idx_logs_user ON activity_logs(user_id)');
    _createPasswordResetsTable(b);
  }

  /// Compte administrateur par défaut (pas d'inscription Admin dans l'app).
  /// Identifiants : admin@resto.tn / Admin@123 — à changer après la 1re connexion.
  Future<void> _seedAdmin(Database db) async {
    final salt = PasswordHasher.generateSalt();
    await db.insert('users', {
      'nom': 'Admin',
      'prenom': 'Principal',
      'email': 'admin@resto.tn',
      'mot_de_passe': PasswordHasher.hash('Admin@123', salt),
      'sel': salt,
      'role': 'ADMIN',
      'statut': 'ACTIF',
      'date_creation': DateTime.now().toIso8601String(),
    });
  }

  /// Utile pour l'historique : vérifie qu'une table d'un autre module existe.
  Future<bool> tableExists(String table) async {
    final db = await database;
    final r = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?", [table]);
    return r.isNotEmpty;
  }
}
