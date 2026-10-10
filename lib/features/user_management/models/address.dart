class Address {
  final int? id;
  final int userId;
  final String libelle; // Maison, Travail...
  final String rue;
  final String ville;
  final double? latitude;
  final double? longitude;
  final bool parDefaut;

  const Address({
    this.id,
    required this.userId,
    required this.libelle,
    required this.rue,
    required this.ville,
    this.latitude,
    this.longitude,
    this.parDefaut = false,
  });

  String get complete => '$rue, $ville';

  factory Address.fromMap(Map<String, Object?> m) => Address(
        id: m['id'] as int?,
        userId: m['user_id'] as int,
        libelle: m['libelle'] as String,
        rue: m['rue'] as String,
        ville: m['ville'] as String,
        latitude: (m['latitude'] as num?)?.toDouble(),
        longitude: (m['longitude'] as num?)?.toDouble(),
        parDefaut: (m['par_defaut'] as int) == 1,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'libelle': libelle,
        'rue': rue,
        'ville': ville,
        'latitude': latitude,
        'longitude': longitude,
        'par_defaut': parDefaut ? 1 : 0,
      };
}
