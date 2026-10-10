import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'auth_exception.dart';

/// Position GPS + adresse lisible via l'API gratuite Nominatim
/// (OpenStreetMap, sans clé).
class GeocodingService {
  Future<Position> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const AuthException('Active la localisation du téléphone.');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      throw const AuthException('Permission de localisation refusée.');
    }
    return Geolocator.getCurrentPosition();
  }

  /// Coordonnées → rue et ville. Champs null si l'adresse est introuvable
  /// ou s'il n'y a pas d'Internet (l'utilisateur complète alors à la main).
  Future<({String? street, String? city})> reverse(double lat, double lng) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'format': 'jsonv2',
        'lat': '$lat',
        'lon': '$lng',
        'accept-language': 'fr',
      });
      final res = await http.get(uri, headers: {
        'User-Agent': 'Bnin-app-projet-academique/1.0',
      }).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return (street: null, city: null);
      final a = ((jsonDecode(res.body) as Map)['address'] as Map?) ?? const {};
      final street = [a['house_number'], a['road'] ?? a['neighbourhood']]
          .whereType<String>()
          .join(' ');
      final city = a['city'] ?? a['town'] ?? a['village'] ?? a['state'];
      return (
        street: street.isEmpty ? null : street,
        city: city?.toString(),
      );
    } catch (_) {
      return (street: null, city: null);
    }
  }
}
