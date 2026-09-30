# Rihla

> Application mobile pour découvrir, noter et organiser la visite de sites touristiques en Algérie, avec mode hors ligne et mode invité.

![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?logo=supabase&logoColor=white)
![SQLite](https://img.shields.io/badge/SQLite-003B57?logo=sqlite&logoColor=white)
![Licence](https://img.shields.io/badge/licence-MIT-green)

## Contexte

**Projet de fin d'études (PFE) de Licence 3 ISIL** (Ingénierie des Systèmes d'Information et des Logiciels) à l'**ESST** (École Supérieure des Sciences et de la Technologie), réalisé **en binôme** avec Zehani Faten Cherine.

L'objectif : proposer une application mobile qui valorise le patrimoine touristique algérien, utilisable même sans connexion et sans compte.

## Fonctionnalités

- **Catalogue de 48 sites touristiques** répartis en 4 catégories principales et couvrant les grandes régions d'Algérie.
- **Recherche et recommandations** : recherche textuelle, filtres par catégorie, et recommandations avec repli sur les sites les mieux notés quand l'utilisateur n'a pas encore d'historique.
- **Fiches détaillées** : photos, adresse, favoris, avis publics (j'aime / je n'aime pas) et ajout à l'itinéraire.
- **Carte interactive** (OpenStreetMap) avec géolocalisation, filtres et marqueurs, itinéraires et trajets multi-étapes via OSRM.
- **Mode invité** : exploration du catalogue sans créer de compte.
- **Authentification** par email et mot de passe : confirmation d'inscription par lien, réinitialisation par lien profond `rihla://auth-callback`, modification de l'email, du mot de passe et du pseudo, suppression de compte.
- **Profil** : avatar, préférences de thème, historique, avis publiés, numéros utiles.
- **Mode hors ligne** : le dernier catalogue chargé reste consultable, et les changements de l'utilisateur sont synchronisés au retour du réseau.

## Stack technique

| Couche | Technologies | Rôle |
|---|---|---|
| Mobile | Flutter, Dart | Application Android et iOS |
| Backend cloud | Supabase (Auth, Postgres, Storage, Edge Functions) | Authentification, catalogue, profils, favoris, historique, avis, avatars |
| Base locale | SQLite (`sqflite`) | Cache hors ligne et file de synchronisation |
| Cartographie | `flutter_map`, OpenStreetMap, OSRM, `geolocator` | Carte, localisation, itinéraires |

## Architecture

```
lib/
  main.dart                   Initialisation conditionnelle de Supabase et de SQLite
  app/                        MaterialApp et thème
  core/
    config/                   Configuration Supabase (dart-define)
    database/                 Schéma SQLite local et accès distant Supabase
    services/                 Auth, synchronisation, profil, favoris, avis, routage
    theme/ utils/ widgets/
  data/
    models/                   Modèles : site, catégorie, avis
    repositories/             Accès aux données
  features/
    auth/                     Accueil, connexion, inscription, confirmation, mot de passe oublié
    discover/                 Exploration du catalogue
    sites/                    Fiche détaillée d'un site
    map/                      Carte interactive
    favorites/                Favoris
    navigation/               Coque de l'application, routeur, navigation en temps réel
    settings/                 Profil et réglages

supabase/
  config.toml                 Configuration du projet Supabase
  functions/delete_account/   Edge Function de suppression de compte
```

**Synchronisation hors ligne.** Les modifications locales sont marquées `dirty`. Le service `UserDataSyncService` envoie les changements locaux avant toute récupération distante, et annule la récupération si l'envoi échoue, pour ne pas écraser des données non synchronisées. La suppression de compte passe par l'Edge Function `delete_account`, qui utilise la clé `service_role` côté serveur uniquement.

## Installation

**Prérequis** : [Flutter](https://docs.flutter.dev/get-started/install) (SDK Dart ≥ 3.11) et un projet [Supabase](https://supabase.com) avec le schéma attendu par l'application.

1. Récupérer les dépendances :
   ```bash
   git clone https://github.com/SamyGoumiri/rihla.git
   cd rihla
   flutter pub get
   ```
2. Lancer l'application en fournissant les paramètres Supabase :
   ```bash
   flutter run \
     --dart-define=SUPABASE_URL=https://xxxxx.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=votre_cle_anon
   ```
3. Construire un APK de production :
   ```bash
   flutter build apk --release \
     --dart-define=SUPABASE_URL=https://xxxxx.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=votre_cle_anon
   ```

Sans `SUPABASE_URL` ni `SUPABASE_ANON_KEY`, l'application démarre pour le développement de l'interface, mais les fonctions cloud (authentification, catalogue distant, synchronisation, avis, avatars) sont indisponibles. Seule la clé publique `anon` doit être embarquée dans l'application ; ne jamais y mettre la clé `service_role`.

## Validation

```bash
dart format --output=none --set-exit-if-changed lib
flutter analyze
```

## Limites connues

- Le schéma Postgres et les politiques RLS sont hébergés sur Supabase et ne sont que partiellement versionnés dans `supabase/migrations/`. Un nouveau projet Supabase demande donc de recréer le schéma manuellement.
- Sur une installation neuve totalement hors ligne, le catalogue reste vide tant qu'une première synchronisation n'a pas eu lieu : l'application affiche alors un état vide explicite plutôt qu'un faux catalogue.
- Pas de suite de tests automatisés ni d'intégration continue dans ce dépôt.

## Licence

Distribué sous licence [MIT](LICENSE).
