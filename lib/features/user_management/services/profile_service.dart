import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../dao/activity_log_dao.dart';
import '../dao/user_dao.dart';
import '../models/activity_log.dart';
import '../models/user.dart';
import 'auth_exception.dart';

/// Modification du profil et de la photo (stockée localement).
class ProfileService {
  final UserDao _users;
  final ActivityLogDao _logs;

  ProfileService({UserDao? users, ActivityLogDao? logs})
      : _users = users ?? UserDao(),
        _logs = logs ?? ActivityLogDao();

  Future<User> updateProfile(User user) async {
    if (await _users.emailExists(user.email.trim().toLowerCase(),
        excludeId: user.id)) {
      throw const AuthException('Cet email est déjà utilisé');
    }
    await _users.updateProfile(user);
    await _logs.log(user.id, LogAction.updateProfile);
    return (await _users.getById(user.id!))!;
  }

  /// Copie l'image choisie dans le dossier de l'app et retourne son chemin.
  Future<String> savePhoto(int userId, String pickedPath) async {
    final dir = await getApplicationDocumentsDirectory();
    final dest = p.join(dir.path, 'avatars',
        'user_${userId}_${DateTime.now().millisecondsSinceEpoch}${p.extension(pickedPath)}');
    await Directory(p.dirname(dest)).create(recursive: true);
    await File(pickedPath).copy(dest);
    return dest;
  }

  Future<void> deleteOwnAccount(int userId) async {
    await _logs.log(userId, LogAction.deleteUser, 'Suppression par l\'utilisateur');
    await _users.delete(userId);
  }
}
