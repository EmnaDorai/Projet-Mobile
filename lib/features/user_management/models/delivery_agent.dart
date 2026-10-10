/// Informations propres au livreur (complète la table users).
class DeliveryAgent {
  final int userId;
  final String? typeVehicule; // Moto, Scooter, Vélo, Voiture
  final bool disponible;
  final String? permisPhoto; // chemin local de la photo du permis
  final double? latitude; // dernière position partagée
  final double? longitude;
  final DateTime? positionMaj;

  const DeliveryAgent({
    required this.userId,
    this.typeVehicule,
    this.disponible = false,
    this.permisPhoto,
    this.latitude,
    this.longitude,
    this.positionMaj,
  });

  bool get hasPosition => latitude != null && longitude != null;
  bool get hasPermis => permisPhoto != null && permisPhoto!.isNotEmpty;

  factory DeliveryAgent.fromMap(Map<String, Object?> m, {int? userId}) => DeliveryAgent(
        userId: userId ?? m['user_id'] as int,
        typeVehicule: m['type_vehicule'] as String?,
        disponible: ((m['disponible'] as int?) ?? 0) == 1,
        permisPhoto: m['permis_photo'] as String?,
        latitude: (m['latitude'] as num?)?.toDouble(),
        longitude: (m['longitude'] as num?)?.toDouble(),
        positionMaj: DateTime.tryParse(m['position_maj'] as String? ?? ''),
      );

  Map<String, Object?> toMap() => {
        'user_id': userId,
        'type_vehicule': typeVehicule,
        'disponible': disponible ? 1 : 0,
        'permis_photo': permisPhoto,
        'latitude': latitude,
        'longitude': longitude,
        'position_maj': positionMaj?.toIso8601String(),
      };

  DeliveryAgent copyWith({
    String? typeVehicule,
    bool? disponible,
    String? permisPhoto,
    double? latitude,
    double? longitude,
    DateTime? positionMaj,
  }) =>
      DeliveryAgent(
        userId: userId,
        typeVehicule: typeVehicule ?? this.typeVehicule,
        disponible: disponible ?? this.disponible,
        permisPhoto: permisPhoto ?? this.permisPhoto,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        positionMaj: positionMaj ?? this.positionMaj,
      );
}
