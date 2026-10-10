import '../../../core/database/database_helper.dart';
import '../models/history_item.dart';

/// ⚠️ Tables des AUTRES membres du groupe.
/// Adapter ces noms aux tables réellement créées par les modules
/// Commandes et Livraison — c'est le seul endroit à modifier.
class HistoryConfig {
  // Module Commandes
  static const ordersTable = 'orders';
  static const orderId = 'id';
  static const orderClientId = 'client_id';
  static const orderDate = 'date_commande';
  static const orderStatus = 'statut';
  static const orderTotal = 'total';

  static const orderItemsTable = 'order_items'; // lignes d'une commande
  static const orderItemOrderId = 'order_id';

  // Module Livraison (si les livraisons sont dans une table séparée)
  static const deliveriesTable = 'deliveries';
  static const deliveryId = 'id';
  static const deliveryAgentId = 'livreur_id';
  static const deliveryOrderId = 'order_id';
  static const deliveryDate = 'date_livraison';
  static const deliveryStatus = 'statut';
}

/// Lecture seule : ce module AFFICHE l'historique, il ne crée ni commandes
/// ni livraisons. Si la table d'un coéquipier n'existe pas encore, les
/// méthodes renvoient une liste vide au lieu de planter.
class HistoryRepository {
  final DatabaseHelper _helper;
  HistoryRepository([DatabaseHelper? helper])
      : _helper = helper ?? DatabaseHelper.instance;

  static const pageSize = 20;

  // ── Historique des commandes d'un client (Client, Manager, Admin) ──
  Future<List<HistoryItem>> getClientOrders(
    int clientId, {
    String? statut,
    DateTime? from,
    DateTime? to,
    int page = 0,
  }) async {
    if (!await _helper.tableExists(HistoryConfig.ordersTable)) return [];
    final db = await _helper.database;
    final where = ['${HistoryConfig.orderClientId} = ?'];
    final args = <Object?>[clientId];
    if (statut != null) {
      where.add('${HistoryConfig.orderStatus} = ?');
      args.add(statut);
    }
    if (from != null) {
      where.add('${HistoryConfig.orderDate} >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('${HistoryConfig.orderDate} <= ?');
      args.add(to.toIso8601String());
    }
    final rows = await db.query(
      HistoryConfig.ordersTable,
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: '${HistoryConfig.orderDate} DESC',
      limit: pageSize,
      offset: page * pageSize,
    );
    return rows
        .map((r) => HistoryItem(
              id: r[HistoryConfig.orderId] as int,
              date: _parseDate(r[HistoryConfig.orderDate]),
              statut: '${r[HistoryConfig.orderStatus] ?? '-'}',
              montant: (r[HistoryConfig.orderTotal] as num?)?.toDouble(),
              description: 'Commande #${r[HistoryConfig.orderId]}',
              raw: r,
            ))
        .toList();
  }

  /// Détail : la commande + ses lignes (si la table de lignes existe).
  Future<({Map<String, Object?>? order, List<Map<String, Object?>> items})>
      getOrderDetail(int orderId) async {
    if (!await _helper.tableExists(HistoryConfig.ordersTable)) {
      return (order: null, items: <Map<String, Object?>>[]);
    }
    final db = await _helper.database;
    final o = await db.query(HistoryConfig.ordersTable,
        where: '${HistoryConfig.orderId} = ?', whereArgs: [orderId], limit: 1);
    var items = <Map<String, Object?>>[];
    if (await _helper.tableExists(HistoryConfig.orderItemsTable)) {
      items = await db.query(HistoryConfig.orderItemsTable,
          where: '${HistoryConfig.orderItemOrderId} = ?', whereArgs: [orderId]);
    }
    return (order: o.isEmpty ? null : o.first, items: items);
  }

  /// Statistiques simples d'un client (fiche Manager).
  Future<({int nbCommandes, double totalDepense})> getClientStats(
      int clientId) async {
    if (!await _helper.tableExists(HistoryConfig.ordersTable)) {
      return (nbCommandes: 0, totalDepense: 0.0);
    }
    final db = await _helper.database;
    final r = await db.rawQuery(
        'SELECT COUNT(*) AS n, COALESCE(SUM(${HistoryConfig.orderTotal}), 0) AS t '
        'FROM ${HistoryConfig.ordersTable} WHERE ${HistoryConfig.orderClientId} = ?',
        [clientId]);
    return (
      nbCommandes: r.first['n'] as int,
      totalDepense: (r.first['t'] as num).toDouble(),
    );
  }

  // ── Historique des livraisons d'un livreur (Livreur, Manager) ──
  Future<List<HistoryItem>> getAgentDeliveries(
    int livreurId, {
    DateTime? from,
    DateTime? to,
    int page = 0,
  }) async {
    if (!await _helper.tableExists(HistoryConfig.deliveriesTable)) return [];
    final db = await _helper.database;
    final where = ['${HistoryConfig.deliveryAgentId} = ?'];
    final args = <Object?>[livreurId];
    if (from != null) {
      where.add('${HistoryConfig.deliveryDate} >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('${HistoryConfig.deliveryDate} <= ?');
      args.add(to.toIso8601String());
    }
    final rows = await db.query(
      HistoryConfig.deliveriesTable,
      where: where.join(' AND '),
      whereArgs: args,
      orderBy: '${HistoryConfig.deliveryDate} DESC',
      limit: pageSize,
      offset: page * pageSize,
    );
    return rows
        .map((r) => HistoryItem(
              id: r[HistoryConfig.deliveryId] as int,
              date: _parseDate(r[HistoryConfig.deliveryDate]),
              statut: '${r[HistoryConfig.deliveryStatus] ?? '-'}',
              description: 'Commande #${r[HistoryConfig.deliveryOrderId] ?? '?'}',
              raw: r,
            ))
        .toList();
  }

  Future<int> countAgentDeliveriesSince(int livreurId, DateTime since) async {
    if (!await _helper.tableExists(HistoryConfig.deliveriesTable)) return 0;
    final db = await _helper.database;
    final r = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM ${HistoryConfig.deliveriesTable} '
        'WHERE ${HistoryConfig.deliveryAgentId} = ? AND ${HistoryConfig.deliveryDate} >= ?',
        [livreurId, since.toIso8601String()]);
    return r.first['n'] as int;
  }

  static DateTime _parseDate(Object? v) =>
      DateTime.tryParse('${v ?? ''}') ?? DateTime.fromMillisecondsSinceEpoch(0);
}
