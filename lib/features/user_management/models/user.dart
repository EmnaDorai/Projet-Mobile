enum UserRole { client, admin, manager, livreur }

enum UserStatus { actif, bloque }

extension UserRoleX on UserRole {
  String get db => name.toUpperCase();
  String get label => const {
        UserRole.client: 'Client',
        UserRole.admin: 'Administrateur',
        UserRole.manager: 'Manager',
        UserRole.livreur: 'Livreur',
      }[this]!;
  static UserRole fromDb(String v) =>
      UserRole.values.firstWhere((r) => r.db == v);
}

extension UserStatusX on UserStatus {
  String get db => this == UserStatus.actif ? 'ACTIF' : 'BLOQUE';
  String get label => this == UserStatus.actif ? 'Actif' : 'Désactivé';
  static UserStatus fromDb(String v) =>
      v == 'BLOQUE' ? UserStatus.bloque : UserStatus.actif;
}

/// Utilisateur de l'application. Le mot de passe et le sel ne sont jamais
/// exposés dans ce modèle (ils restent dans la couche DAO/Auth).
class User {
  final int? id;
  final String nom;
  final String prenom;
  final String email;
  final String? telephone;
  final String? photo;
  final UserRole role;
  final UserStatus statut;
  final String? questionSecurite;
  final DateTime dateCreation;

  const User({
    this.id,
    required this.nom,
    required this.prenom,
    required this.email,
    this.telephone,
    this.photo,
    required this.role,
    this.statut = UserStatus.actif,
    this.questionSecurite,
    required this.dateCreation,
  });

  String get nomComplet => '$prenom $nom';
  bool get estBloque => statut == UserStatus.bloque;

  factory User.fromMap(Map<String, Object?> m) => User(
        id: m['id'] as int?,
        nom: m['nom'] as String,
        prenom: m['prenom'] as String,
        email: m['email'] as String,
        telephone: m['telephone'] as String?,
        photo: m['photo'] as String?,
        role: UserRoleX.fromDb(m['role'] as String),
        statut: UserStatusX.fromDb(m['statut'] as String),
        questionSecurite: m['question_securite'] as String?,
        dateCreation: DateTime.parse(m['date_creation'] as String),
      );

  /// Champs modifiables (sans identifiants de connexion).
  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'nom': nom,
        'prenom': prenom,
        'email': email,
        'telephone': telephone,
        'photo': photo,
        'role': role.db,
        'statut': statut.db,
        'question_securite': questionSecurite,
        'date_creation': dateCreation.toIso8601String(),
      };

  User copyWith({
    String? nom,
    String? prenom,
    String? email,
    String? telephone,
    String? photo,
    UserRole? role,
    UserStatus? statut,
    String? questionSecurite,
  }) =>
      User(
        id: id,
        nom: nom ?? this.nom,
        prenom: prenom ?? this.prenom,
        email: email ?? this.email,
        telephone: telephone ?? this.telephone,
        photo: photo ?? this.photo,
        role: role ?? this.role,
        statut: statut ?? this.statut,
        questionSecurite: questionSecurite ?? this.questionSecurite,
        dateCreation: dateCreation,
      );
}
