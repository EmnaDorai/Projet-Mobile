import '../../../core/database/database_helper.dart';
import '../models/activity_log.dart';

class ActivityLogDao {
  final DatabaseHelper _helper;
  ActivityLogDao([DatabaseHelper? helper]) : _helper = helper ?? DatabaseHelper.instance;

  Future<void> log(int? userId, String action, [String? details]) async {
    final db = await _helper.database;
    await db.insert(
        'activity_logs',
        ActivityLog(
          userId: userId,
          action: action,
          details: details,
          date: DateTime.now(),
        ).toMap());
  }

  Future<List<ActivityLog>> getAll({
    String? action,
    int? userId,
    DateTime? from,
    DateTime? to,
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await _helper.database;
    final where = <String>[];
    final args = <Object?>[];
    if (action != null) {
      where.add('l.action = ?');
      args.add(action);
    }
    if (userId != null) {
      where.add('l.user_id = ?');
      args.add(userId);
    }
    if (from != null) {
      where.add('l.date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('l.date <= ?');
      args.add(to.toIso8601String());
    }
    final r = await db.rawQuery('''
      SELECT l.*, u.email FROM activity_logs l
      LEFT JOIN users u ON u.id = l.user_id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY l.date DESC
      LIMIT ? OFFSET ?
    ''', [...args, limit, offset]);
    return r.map(ActivityLog.fromMap).toList();
  }

  Future<List<ActivityLog>> getByUser(int userId, {int limit = 50}) =>
      getAll(userId: userId, limit: limit);
}
