/// Clés des services externes du module Gestion utilisateurs.
///
/// ⚠️ Projet académique : les clés sont dans l'app pour simplifier la démo.
/// En production, l'envoi d'email/SMS passerait par un serveur.
/// Ne publie pas ce fichier rempli sur un dépôt GitHub public.
class ApiConfig {
  // ───────── EmailJS (https://www.emailjs.com) ─────────
  // Account → General : Public Key ; Email Services : Service ID ;
  // Email Templates : Template ID ; Account → Security : Private Key.
  static const emailJsServiceId = 'service_wscenha';
  static const emailJsTemplateId = 'template_l2067pe';
  static const emailJsPublicKey = 'mLgbzoVMCL8JAiFwM';
  /// 2e modèle EmailJS : notification « compte activé / désactivé ».
  static const emailJsStatusTemplateId = 'template_5761i25';
  static const emailJsPrivateKey = 'COLLER_ICI_PRIVATE_KEY';

  // ───────── Infobip (https://portal.infobip.com) ─────────
  // Page d'accueil du portail : « API key » et « Base URL »
  // (ex. xxxxx.api.infobip.com, sans https://).
  static const infobipBaseUrl = 'COLLER_ICI_BASE_URL';
  static const infobipApiKey = 'COLLER_ICI_API_KEY';

  /// Nom d'expéditeur. En compte d'essai, garder 'InfoSMS'.
  static const infobipSender = 'InfoSMS';

  /// Indicatif ajouté aux numéros saisis sans indicatif (8 chiffres).
  static const defaultCountryCode = '+216';

  static bool get emailJsConfigured =>
      !emailJsServiceId.startsWith('COLLER') &&
      !emailJsTemplateId.startsWith('COLLER') &&
      !emailJsPublicKey.startsWith('COLLER');

  static bool get emailJsStatusConfigured =>
      emailJsConfigured && !emailJsStatusTemplateId.startsWith('COLLER');

  static bool get infobipConfigured =>
      !infobipBaseUrl.startsWith('COLLER') && !infobipApiKey.startsWith('COLLER');
}
