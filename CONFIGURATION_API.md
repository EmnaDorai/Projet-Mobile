# Configuration des API externes — Bnin (module Gestion utilisateurs)

Toutes les clés se collent dans **`lib/core/config/api_config.dart`**.
Tant qu'une clé n'est pas remplie, l'app affiche un message clair au lieu de planter.

| Fonction | Service | Coût | Où l'utiliser dans l'app |
|---|---|---|---|
| Code de réinitialisation par email | EmailJS (API REST) | Gratuit, 200 emails/mois | Mot de passe oublié → « Recevoir un code par email » |
| Code de réinitialisation par SMS | Infobip (API REST) | Crédit d'essai gratuit | Mot de passe oublié → « Recevoir un code par SMS » |
| Connexion par empreinte / visage | Biométrie Android (`local_auth`) | Gratuit, aucune clé | Profil → interrupteur, puis bouton sur l'écran de connexion |
| Connexion avec Google | Google Sign-In (OAuth 2.0) | Gratuit | Connexion → « Continuer avec Google » |

---

## 1. EmailJS — envoi du code par email

1. Crée un compte sur https://www.emailjs.com.
2. **Email Services → Add New Service → Gmail** → connecte ton Gmail → note le **Service ID**.
3. **Email Templates → Create New Template** :
   - **To Email** : `{{to_email}}`
   - **Subject** : `Ton code Bnin : {{code}}`
   - **Content** :
     ```
     Bonjour {{to_name}},

     Voici ton code pour réinitialiser ton mot de passe {{app_name}} : {{code}}
     Il expire dans 10 minutes. Si tu n'as rien demandé, ignore cet email.
     ```
   - Enregistre → note le **Template ID**.
4. **Account → General** → note la **Public Key**.
5. **Account → Security** :
   - ✅ coche **« Allow EmailJS API for non-browser applications »** (obligatoire, sinon erreur 403) ;
   - note la **Private Key** (Access Token).
6. Colle les 4 valeurs dans `api_config.dart` (`emailJsServiceId`, `emailJsTemplateId`, `emailJsPublicKey`, `emailJsPrivateKey`).

## 2. Infobip — envoi du code par SMS

1. Crée un compte d'essai sur https://www.infobip.com/signup (le numéro de téléphone saisi à l'inscription est celui qui recevra les SMS de test).
2. Sur la page d'accueil du portail (https://portal.infobip.com), copie :
   - **API key** (bouton « Copy » ou menu **Developers → API keys**) ;
   - **Base URL**, de la forme `xxxxx.api.infobip.com`.
3. Colle-les dans `api_config.dart` (`infobipApiKey`, `infobipBaseUrl`). Garde `infobipSender = 'InfoSMS'`.

⚠️ Compte d'essai : les SMS ne partent que vers **le numéro enregistré sur Infobip**. Mets ce même numéro dans le profil du compte de l'app (8 chiffres → `+216` ajouté automatiquement).

## 3. Biométrie — rien à configurer

- Le téléphone doit avoir une **empreinte ou un visage enregistré** (Paramètres → Mots de passe et sécurité).
- Dans l'app : connecte-toi avec ton mot de passe → **Profil → Connexion par empreinte ou visage** → active et confirme.
- Déconnecte-toi : le bouton **« Empreinte ou visage »** apparaît sur l'écran de connexion.

L'app ne voit jamais l'empreinte ni le visage : Android vérifie l'identité et répond seulement oui/non.
Sur certains téléphones (dont beaucoup de Xiaomi), le déverrouillage facial n'est pas assez sécurisé pour les apps : Android proposera alors l'empreinte.

## 4. Google Sign-In

1. Récupère l'empreinte **SHA-1** de ta clé de debug :
   ```bat
   cd android
   gradlew signingReport
   ```
   Cherche le bloc `Variant: debug` → copie la ligne `SHA1: AA:BB:…`.
2. https://console.cloud.google.com → **Nouveau projet** (ex. « Bnin »).
3. **API et services → Écran de consentement OAuth** → type **Externe** → remplis le nom de l'app et ton email → dans **Utilisateurs test**, ajoute les comptes Gmail qui testeront.
4. **API et services → Identifiants → Créer des identifiants → ID client OAuth** → type **Android** :
   - Nom du package : `com.example.restaurant_app`
   - Empreinte SHA-1 : celle de l'étape 1
5. Rien à coller dans l'app : Google reconnaît l'app grâce au package et au SHA-1 (la propagation peut prendre quelques minutes).

Si un compte Google n'existe pas encore dans l'app, un **compte client** est créé automatiquement avec son email.
Il peut ensuite définir un mot de passe via « Mot de passe oublié ».

---

## Sécurité (à mentionner dans le rapport)

- Codes à 6 chiffres générés aléatoirement (`Random.secure`), **stockés hachés**, valables **10 min**, **5 essais** max, **un envoi par minute**.
- Un seul code actif par compte ; il est consommé après usage.
- Limite : sans serveur, les clés EmailJS/Infobip sont dans l'app. En production, l'envoi passerait par un backend qui garde les clés secrètes.
