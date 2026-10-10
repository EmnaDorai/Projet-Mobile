import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

/// Nom lisible de l'appareil, enregistré à chaque connexion
/// (ex. « Xiaomi 23106RN0DA · Android 14 »).
class DeviceInfoService {
  static String? _cached;

  static Future<String> describe() async {
    if (_cached != null) return _cached!;
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        _cached = '${_cap(a.manufacturer)} ${a.model} · Android ${a.version.release}';
      } else if (Platform.isIOS) {
        final i = await info.iosInfo;
        _cached = '${i.name} · iOS ${i.systemVersion}';
      } else {
        _cached = Platform.operatingSystem;
      }
    } catch (_) {
      _cached = 'Appareil inconnu';
    }
    return _cached!;
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
