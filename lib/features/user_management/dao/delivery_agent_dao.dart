import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../models/delivery_agent.dart';
import '../models/user.dart';

class DeliveryAgentDao {
  final DatabaseHelper _helper;
  DeliveryAgentDao([DatabaseHelper? helper])
      : _helper = helper ?? DatabaseHelper.instance;

  Future<DeliveryAgent> getProfile(int userId) async {
    final db = await _helper.database;
    final r = await db
        .query('delivery_agents', where: 'user_id = ?', whereArgs: [userId]);
    return r.isEmpty ? DeliveryAgent(userId: userId) : DeliveryAgent.fromMap(r.first);
  }

  Future<void> save(DeliveryAgent a) async {
    final db = await _helper.database;
    await db.insert('delivery_agents', a.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> setAvailability(int userId, bool disponible) async {
    final current = await getProfile(userId);
    await save(current.copyWith(disponible: disponible));
  }

  /// Position partagée par le livreur (carte du Manager).
  Future<void> updatePosition(int userId, double lat, double lng) async {
    final current = await getProfile(userId);
    await save(current.copyWith(
        latitude: lat, longitude: lng, positionMaj: DateTime.now()));
  }

  Future<void> setPermisPhoto(int userId, String path) async {
    final current = await getProfile(userId);
    await save(current.copyWith(permisPhoto: path));
  }

  /// Livreurs + leur profil (pour le Manager et le module Livraison).
  Future<List<(User, DeliveryAgent)>> getAllWithProfile(
      {bool? disponible, String? search}) async {
    final db = await _helper.database;
    final where = ["u.role = 'LIVREUR'"];
    final args = <Object?>[];
    if (disponible != null) {
      where.add('COALESCE(d.disponible, 0) = ?');
      args.add(disponible ? 1 : 0);
    }
    if (search != null && search.trim().isNotEmpty) {
      where.add('(u.nom LIKE ? OR u.prenom LIKE ? OR u.telephone LIKE ?)');
      final s = '%${search.trim()}%';
      args.addAll([s, s, s]);
    }
    final r = await db.rawQuery('''
      SELECT u.id, u.nom, u.prenom, u.email, u.telephone, u.photo, u.role,
             u.statut, u.question_securite, u.date_creation,
             d.type_vehicule, COALESCE(d.disponible, 0) AS disponible,
             d.permis_photo, d.latitude, d.longitude, d.position_maj
      FROM users u LEFT JOIN delivery_agents d ON d.user_id = u.id
      WHERE ${where.join(' AND ')}
      ORDER BY disponible DESC, u.nom
    ''', args);
    return r
        .map((m) => (
              User.fromMap(m),
              DeliveryAgent.fromMap(m, userId: m['id'] as int),
            ))
        .toList();
  }
}
