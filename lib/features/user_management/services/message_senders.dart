import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import 'auth_exception.dart';

/// Envoi d'email via l'API REST d'EmailJS.
/// Le modèle EmailJS doit utiliser les variables {{to_email}}, {{to_name}},
/// {{code}} et {{app_name}}.
class EmailJsSender {
  static final _endpoint = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

  Future<void> sendResetCode({
    required String toEmail,
    required String toName,
    required String code,
  }) async {
    if (!ApiConfig.emailJsConfigured) {
      throw const AuthException(
          'L\'envoi d\'email n\'est pas encore configuré (clés EmailJS manquantes).');
    }
    final body = {
      'service_id': ApiConfig.emailJsServiceId,
      'template_id': ApiConfig.emailJsTemplateId,
      'user_id': ApiConfig.emailJsPublicKey,
      if (!ApiConfig.emailJsPrivateKey.startsWith('COLLER'))
        'accessToken': ApiConfig.emailJsPrivateKey,
      // Plusieurs noms pour la même valeur : compatible avec notre modèle
      // ({{to_email}}, {{code}}) et le modèle EmailJS « One-Time Password »
      // ({{email}}, {{passcode}}, {{time}}).
      'template_params': {
        'to_email': toEmail,
        'email': toEmail,
        'to_name': toName,
        'name': toName,
        'code': code,
        'passcode': code,
        'time': _expiryTime(),
        'app_name': 'Bnin',
        'company_name': 'Bnin',
      },
    };
    final http.Response res;
    try {
      res = await http
          .post(_endpoint,
              headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const AuthException('Pas de connexion Internet : email non envoyé.');
    }
    if (res.statusCode != 200) {
      throw AuthException('Échec de l\'envoi de l\'email (${res.statusCode}) : ${res.body}');
    }
  }
}

extension NoticeMail on EmailJsSender {
  /// Email d'information (2e modèle EmailJS : {{subject}}, {{title}},
  /// {{message}}). Utilisé pour le statut du compte et l'email groupé.
  Future<void> sendNotice({
    required String toEmail,
    required String toName,
    required String subject,
    required String title,
    required String message,
  }) async {
    if (!ApiConfig.emailJsStatusConfigured) {
      throw const AuthException('modèle EmailJS « statut » non configuré');
    }
    final body = {
      'service_id': ApiConfig.emailJsServiceId,
      'template_id': ApiConfig.emailJsStatusTemplateId,
      'user_id': ApiConfig.emailJsPublicKey,
      if (!ApiConfig.emailJsPrivateKey.startsWith('COLLER'))
        'accessToken': ApiConfig.emailJsPrivateKey,
      'template_params': {
        'to_email': toEmail,
        'email': toEmail,
        'to_name': toName,
        'name': toName,
        'app_name': 'Bnin',
        'subject': subject,
        'title': title,
        'message': message,
      },
    };
    final http.Response res;
    try {
      res = await http
          .post(EmailJsSender._endpoint,
              headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const AuthException('pas de connexion Internet');
    }
    if (res.statusCode != 200) {
      throw AuthException('erreur EmailJS ${res.statusCode}');
    }
  }

  /// Prévient l'utilisateur que son compte a été activé ou désactivé.
  Future<void> sendAccountStatus({
    required String toEmail,
    required String toName,
    required bool active,
    required String roleLabel,
  }) =>
      sendNotice(
        toEmail: toEmail,
        toName: toName,
        subject: active
            ? 'Votre compte Bnin est activé'
            : 'Votre compte Bnin a été désactivé',
        title: active ? 'Compte activé ✅' : 'Compte désactivé',
        message: active
            ? 'Bonne nouvelle ! Votre compte $roleLabel a été activé par '
                'l\'administrateur. Vous pouvez maintenant vous connecter à '
                'l\'application Bnin.'
            : 'Votre compte $roleLabel a été désactivé par l\'administrateur. '
                'Vous ne pouvez plus vous connecter pour le moment. Pour toute '
                'question, contactez le restaurant.',
      );
}

/// Heure d'expiration du code (10 min), ex. « 10:42 ».
String _expiryTime() {
  final t = DateTime.now().add(const Duration(minutes: 10));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)}';
}

/// Envoi de SMS via l'API REST d'Infobip.
/// Compte d'essai : les SMS ne partent que vers le numéro enregistré
/// à l'inscription sur Infobip.
class InfobipSmsSender {
  Future<void> sendResetCode({required String phone, required String code}) async {
    if (!ApiConfig.infobipConfigured) {
      throw const AuthException(
          'L\'envoi de SMS n\'est pas encore configuré (clés Infobip manquantes).');
    }
    final host = ApiConfig.infobipBaseUrl
        .replaceFirst(RegExp(r'^https?://'), '')
        .replaceAll('/', '');
    final uri = Uri.https(host, '/sms/2/text/advanced');
    final body = {
      'messages': [
        {
          'destinations': [
            {'to': normalizePhone(phone).replaceFirst('+', '')}
          ],
          'from': ApiConfig.infobipSender,
          'text': 'Bnin : ton code de réinitialisation est $code. '
              'Il expire dans 10 minutes.',
        }
      ]
    };
    final http.Response res;
    try {
      res = await http
          .post(uri,
              headers: {
                'Authorization': 'App ${ApiConfig.infobipApiKey}',
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode(body))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const AuthException('Pas de connexion Internet : SMS non envoyé.');
    }

    if (res.statusCode == 401) {
      throw const AuthException('Clé API Infobip invalide (vérifie API key et Base URL).');
    }
    Map<String, dynamic>? json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      // Réponse non JSON : traitée ci-dessous.
    }
    if (res.statusCode >= 300) {
      final text = json?['requestError']?['serviceException']?['text'] ?? res.body;
      throw AuthException('Échec de l\'envoi du SMS : $text');
    }
    // 200 : Infobip indique le statut du message (PENDING = accepté).
    final status = (json?['messages'] as List?)?.firstOrNull?['status'] as Map?;
    final group = status?['groupName']?.toString();
    if (group == 'REJECTED' || group == 'UNDELIVERABLE') {
      throw AuthException(
          'SMS refusé par Infobip : ${status?['description'] ?? group}');
    }
  }

  /// « 26 698 314 » → « +21626698314 ».
  static String normalizePhone(String raw) {
    final p = raw.replaceAll(RegExp(r'[\s.-]'), '');
    if (p.startsWith('+')) return p;
    if (p.startsWith('00')) return '+${p.substring(2)}';
    return '${ApiConfig.defaultCountryCode}$p';
  }

  /// Affichage masqué : « •••• 314 ».
  static String mask(String raw) {
    final p = normalizePhone(raw);
    return p.length <= 4 ? p : '•••• ${p.substring(p.length - 3)}';
  }
}
