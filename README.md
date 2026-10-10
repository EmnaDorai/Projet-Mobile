# Module Gestion des utilisateurs — App Restauration (Flutter + SQLite)

Module responsable de : **authentification**, **profils des 4 acteurs**, **gestion des comptes (Admin)**, **espaces Client / Admin / Manager / Livreur** et **affichage des historiques**.

> Le module **affiche** l'historique des commandes et des livraisons, il ne les **crée** pas (modules Commandes / Livraison des coéquipiers).

---

## 1. Installation

1. Copier le dossier `lib/features/user_management/` dans le projet du groupe.
2. Copier `lib/core/database/database_helper.dart` (**base partagée** — voir §4).
3. Ajouter les dépendances de `pubspec.yaml` puis `flutter pub get`.
4. Dans `main.dart` : `ChangeNotifierProvider(create: (_) => AuthProvider())` et `home: const RoleRouter()` (voir `lib/main.dart`).

### Permissions natives
| Fonction | Android (`AndroidManifest.xml`) | iOS (`Info.plist`) |
|---|---|---|
| Photo de profil (`image_picker`) | — | `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` |
| Position de l'adresse (`geolocator`) | `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` | `NSLocationWhenInUseUsageDescription` |

### Compte administrateur par défaut
`admin@resto.tn` / `Admin@123` (créé au 1er lancement — à changer ensuite).

---

## 2. Architecture

```
lib/
├─ core/database/database_helper.dart      Base SQLite partagée + tables du module + seed admin
└─ features/user_management/
   ├─ models/      User, Address, Preference, DeliveryAgent, ActivityLog, HistoryItem
   ├─ dao/         UserDao, AddressDao, PreferenceDao, DeliveryAgentDao,
   │               ActivityLogDao, HistoryRepository (lecture des tables des autres modules)
   ├─ services/    AuthService, AdminService, ProfileService, SessionService, PasswordHasher
   ├─ providers/   AuthProvider (utilisateur connecté, accessible par tous les modules)
   ├─ widgets/     composants communs (avatar, chips, stats, validateurs…)
   └─ screens/
      ├─ role_router.dart        Connexion puis redirection selon le rôle
      ├─ auth/                   Connexion, Inscription, Mot de passe oublié
      ├─ common/                 Profil, Modifier profil, Mot de passe, Question de sécurité,
      │                          Historique commandes, Détail commande, Historique livraisons
      ├─ client/                 Accueil client, Adresses, Formulaire adresse, Préférences
      ├─ admin/                  Tableau de bord, Utilisateurs, Fiche, Création, Journal
      ├─ manager/                Accueil manager, Liste livreurs
      └─ livreur/                Accueil (disponibilité + stats), Historique, Véhicule
```

---

## 3. Contenu des espaces

| Espace | Onglets / écrans | Fonctionnalités |
|---|---|---|
| **Auth** | Connexion, Inscription, Mot de passe oublié | Inscription client avec question de sécurité ; blocage si compte bloqué ; session persistante |
| **Client** | Historique · Adresses · Profil | Historique paginé + filtres statut/période, détail commande, CRUD adresses (+ GPS, par défaut), préférences (allergies, langue, notifications), suppression du compte |
| **Admin** | Accueil · Utilisateurs · Journal · Profil | Stats (total, nouveaux 7 j, bloqués, répartition par rôle), recherche/filtres, création Manager/Livreur/Admin, changer rôle, bloquer/débloquer, réinitialiser mot de passe, supprimer, historique + activité de chaque utilisateur, journal global filtrable |
| **Manager** | Clients · Livreurs · Profil | Fiches clients (nb commandes, total dépensé, historique), livreurs filtrés en ligne/hors ligne, fiche livreur (véhicule, livraisons 30 j, historique) — lecture seule |
| **Livreur** | Accueil · Historique · Profil | Interrupteur en ligne/hors ligne, livraisons du jour et du mois, historique filtré par période, type de véhicule |
| **Commun** | Profil | Modifier infos + photo, changer mot de passe, question de sécurité, déconnexion |

Règles de sécurité : mots de passe hachés SHA-256 + sel, 8 car. / 1 majuscule / 1 chiffre ; un admin ne peut pas se bloquer, se supprimer ni changer son propre rôle ; il reste toujours au moins un admin ; toutes les actions sensibles sont tracées dans `activity_logs`.

---

## 4. ⚠️ À coordonner avec le groupe

### Une seule base SQLite
Tout le monde utilise `DatabaseHelper.instance`. Chaque membre ajoute la création de ses tables dans `_onCreate` (et incrémente `_dbVersion` + migration dans `_onUpgrade` après la première livraison).

### Tables dont l'historique dépend
Les noms sont centralisés dans **`dao/history_repository.dart` → `HistoryConfig`** : c'est le seul endroit à modifier si vos coéquipiers utilisent d'autres noms.

| Table (module) | Colonnes attendues |
|---|---|
| `orders` (Commandes) | `id`, `client_id → users.id`, `date_commande` (ISO 8601), `statut`, `total` |
| `order_items` (Commandes) | `order_id`, `nom_plat`/`nom`, `quantite`, `prix_unitaire` |
| `deliveries` (Livraison) | `id`, `livreur_id → users.id`, `order_id`, `date_livraison`, `statut` |

- Les statuts des filtres (`EN_COURS`, `LIVREE`, `ANNULEE`) sont dans `order_history_view.dart` → à aligner avec le module Commandes.
- Si une table n'existe pas encore, l'historique s'affiche vide (pas de plantage) : vous pouvez développer en parallèle.
- **Suppression de compte** : demander aux coéquipiers de déclarer leurs clés étrangères vers `users` avec `ON DELETE SET NULL` (sinon la suppression d'un client ayant des commandes sera refusée par SQLite).

### Ce que les autres modules peuvent utiliser
- `context.read<AuthProvider>().currentUser` → utilisateur connecté (id, rôle…)
- `AddressDao().getDefault(userId)` / `getByUser(userId)` → adresse de livraison
- `DeliveryAgentDao().getAllWithProfile(disponible: true)` → livreurs disponibles pour l'affectation
- `PreferenceDao().get(userId)` → allergies du client

---

## 5. Limites (à citer dans le rapport)
- SQLite = données sur **un seul téléphone** : démonstration en changeant de compte sur le même appareil. Perspective : Firebase ou backend REST.
- Pas d'email/SMS sans serveur → récupération par question de sécurité ou réinitialisation par l'Admin.
