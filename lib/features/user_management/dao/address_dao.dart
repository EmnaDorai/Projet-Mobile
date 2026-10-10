import '../../../core/database/database_helper.dart';
import '../models/address.dart';

class AddressDao {
  final DatabaseHelper _helper;
  AddressDao([DatabaseHelper? helper]) : _helper = helper ?? DatabaseHelper.instance;

  Future<List<Address>> getByUser(int userId) async {
    final db = await _helper.database;
    final r = await db.query('addresses',
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'par_defaut DESC, id DESC');
    return r.map(Address.fromMap).toList();
  }

  /// Adresse par défaut (utilisée aussi par le module Commande).
  Future<Address?> getDefault(int userId) async {
    final db = await _helper.database;
    final r = await db.query('addresses',
        where: 'user_id = ? AND par_defaut = 1', whereArgs: [userId], limit: 1);
    return r.isEmpty ? null : Address.fromMap(r.first);
  }

  /// La première adresse d'un utilisateur devient automatiquement par défaut.
  Future<int> insert(Address a) async {
    final db = await _helper.database;
    return db.transaction((txn) async {
      final existing = await txn
          .query('addresses', where: 'user_id = ?', whereArgs: [a.userId]);
      final makeDefault = a.parDefaut || existing.isEmpty;
      if (makeDefault) {
        await txn.update('addresses', {'par_defaut': 0},
            where: 'user_id = ?', whereArgs: [a.userId]);
      }
      final map = a.toMap()
        ..remove('id')
        ..['par_defaut'] = makeDefault ? 1 : 0;
      return txn.insert('addresses', map);
    });
  }

  Future<int> update(Address a) async {
    final db = await _helper.database;
    return db.transaction((txn) async {
      if (a.parDefaut) {
        await txn.update('addresses', {'par_defaut': 0},
            where: 'user_id = ?', whereArgs: [a.userId]);
      }
      return txn.update('addresses', a.toMap(),
          where: 'id = ? AND user_id = ?', whereArgs: [a.id, a.userId]);
    });
  }

  Future<void> setDefault(int userId, int addressId) async {
    final db = await _helper.database;
    await db.transaction((txn) async {
      await txn.update('addresses', {'par_defaut': 0},
          where: 'user_id = ?', whereArgs: [userId]);
      await txn.update('addresses', {'par_defaut': 1},
          where: 'id = ? AND user_id = ?', whereArgs: [addressId, userId]);
    });
  }

  /// Si l'adresse supprimée était par défaut, la plus récente la remplace.
  Future<void> delete(int userId, int addressId) async {
    final db = await _helper.database;
    await db.transaction((txn) async {
      final r = await txn.query('addresses',
          columns: ['par_defaut'],
          where: 'id = ? AND user_id = ?',
          whereArgs: [addressId, userId]);
      if (r.isEmpty) return;
      final wasDefault = (r.first['par_defaut'] as int) == 1;
      await txn.delete('addresses',
          where: 'id = ? AND user_id = ?', whereArgs: [addressId, userId]);
      if (wasDefault) {
        await txn.rawUpdate('''
          UPDATE addresses SET par_defaut = 1
          WHERE id = (SELECT id FROM addresses WHERE user_id = ? ORDER BY id DESC LIMIT 1)
        ''', [userId]);
      }
    });
  }
}
