import 'package:shared_preferences/shared_preferences.dart';

/// Garde l'utilisateur connecté entre deux lancements de l'app.
class SessionService {
  static const _kUserId = 'session_user_id';
  static const _kRole = 'session_role';

  Future<void> save(int userId, String role) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kUserId, userId);
    await p.setString(_kRole, role);
  }

  Future<int?> currentUserId() async =>
      (await SharedPreferences.getInstance()).getInt(_kUserId);

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kUserId);
    await p.remove(_kRole);
  }
}
