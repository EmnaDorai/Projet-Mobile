import 'package:sqflite/sqflite.dart';

import '../../../core/database/database_helper.dart';
import '../models/preference.dart';

class PreferenceDao {
  final DatabaseHelper _helper;
  PreferenceDao([DatabaseHelper? helper]) : _helper = helper ?? DatabaseHelper.instance;

  /// Retourne les préférences ou des valeurs par défaut si aucune ligne.
  Future<Preference> get(int userId) async {
    final db = await _helper.database;
    final r = await db.query('preferences', where: 'user_id = ?', whereArgs: [userId]);
    return r.isEmpty ? Preference(userId: userId) : Preference.fromMap(r.first);
  }

  Future<void> save(Preference p) async {
    final db = await _helper.database;
    await db.insert('preferences', p.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
