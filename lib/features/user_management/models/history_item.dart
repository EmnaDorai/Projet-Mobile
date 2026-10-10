/// Élément d'historique générique (commande pour un client, livraison pour un
/// livreur). Construit à partir des tables des AUTRES modules — voir
/// HistoryConfig pour faire correspondre les noms de colonnes.
class HistoryItem {
  final int id;
  final DateTime date;
  final String statut;
  final double? montant;
  final String? description;
  final Map<String, Object?> raw; // ligne complète, pour l'écran de détail

  const HistoryItem({
    required this.id,
    required this.date,
    required this.statut,
    this.montant,
    this.description,
    this.raw = const {},
  });
}
