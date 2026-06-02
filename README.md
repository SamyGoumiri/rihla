# Rihla - Application mobile touristique algerienne

Projet de fin d'etudes (PFE) L3-ISIL, Ecole Superieure des Sciences et
Technologies (ESST). Rihla est une application Flutter pour explorer,
commenter et organiser des consultations de sites touristiques en Algerie,
avec un backend Supabase, une base locale SQLite et un mode invite
utilisable sans compte.

## Etat de la stack

| Couche | Choix actuel | Role |
|---|---|---|
| Mobile | Flutter / Dart | Android, iOS |
| Backend cloud | Supabase Auth + Postgres + Storage | Authentification, catalogue, profils, favoris, historique, avis, avatars |
| Base locale | SQLite via `sqflite` | Cache offline du catalogue et file de synchronisation locale |
| Carte / routing | OpenStreetMap + OSRM | Tuiles, itineraire, trip multi-etapes |

## Fonctionnalites

- Catalogue de 48 sites touristiques et 4 categories principales servis par
  Supabase, couvrant les grandes regions d'Algerie.
- Recherche texte, filtres par categorie et recommandations avec repli vers
  les sites les mieux notes quand l'utilisateur n'a pas encore d'historique.
- Fiches detail avec photos, adresse, favoris, avis publics (likes/dislikes)
  et ajout a l'itineraire.
- Carte interactive Flutter Map avec geolocalisation, filtres, marqueurs et
  attribution OpenStreetMap.
- Mode invite local pour explorer le catalogue sans creer de compte.
- Authentification email/mot de passe Supabase, confirmation d'inscription
  par lien email, reset password par deep link `rihla://auth-callback`,
  modification email/mot de passe/pseudo.
- Profil, preferences de theme, avatar Supabase Storage.
- Offline SQL : les derniers sites/categories charges restent consultables via
  SQLite ; les changements utilisateur sont marques `dirty` puis pousses vers
  Supabase au retour reseau.
- Avis publics lisibles par tous, ecriture reservee au proprietaire.

## Demarrage rapide

```bash
flutter pub get
flutter analyze
flutter run \
  --dart-define=SUPABASE_URL=https://xxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
```

Sans `SUPABASE_URL` et `SUPABASE_ANON_KEY`, l'app peut demarrer pour du
developpement UI local, mais les fonctions cloud sont indisponibles :
authentification, catalogue distant, sync, avis publics et avatars.

## Builds Android

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://xxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...

flutter build appbundle --release \
  --dart-define=SUPABASE_URL=https://xxxxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
```

Sans `SUPABASE_URL` et `SUPABASE_ANON_KEY`, le build se lance mais l'APK est
deconnecte du backend : authentification, catalogue distant, sync, avis publics
et avatars sont alors indisponibles.

## Architecture

```text
lib/
  main.dart                         # init Supabase conditionnelle + SQLite
  app/                              # MaterialApp, theme
  core/
    config/supabase_config.dart     # dart-define runtime
    database/local_database.dart    # schema SQLite local
    database/remote_database.dart   # abstraction Supabase/PostgREST
    services/                       # auth, sync, profil, photo, routing
  data/
    models/                         # TouristSite, SiteCategory, SiteReview
    repositories/                   # SiteRepository, CategoryRepository
  features/
    auth/                           # welcome, login, signup, email_sent, account_confirmed, reset_password
    discover/                       # page Explorer
    sites/                          # fiche detail
    map/                            # carte
    settings/                       # profil et reglages (apparence, compte, confidentialite)
    favorites/                      # liste favoris ouverte depuis le profil
    navigation/                     # AppShell + AppRouter + navigation temps reel

supabase/
  config.toml                       # configuration projet Supabase
  functions/delete_account/         # Edge Function : suppression de compte
```

Le backend cloud (schema Postgres, RLS, buckets Storage `sites` et `avatars`)
est heberge sur Supabase. La suppression de compte passe par l'Edge Function
`delete_account`, qui s'appuie sur la `service_role` pour effacer l'utilisateur
et ses donnees en cascade.

## Synchronisation offline

SQLite stocke localement :

- catalogue : `sites`, `categories`, `site_categories`;
- donnees utilisateur : `profiles`, `favorites`, `view_history`, `ratings`,
  `reviews`;
- etat : `sync_state`.

Les mutations locales passent `dirty = 1`. `UserDataSyncService` pousse les
changements locaux avant tout pull distant. Si le push echoue, le pull est
annule pour eviter d'ecraser des donnees offline non synchronisees par une
ancienne version cloud.

Limite connue : sur une installation neuve totalement hors ligne, le catalogue
et les categories restent vides tant qu'un premier pull Supabase n'a pas hydrate
SQLite. L'application affiche alors un etat vide ou indisponible explicite,
plutot qu'un catalogue fictif embarque.

## Validation

```bash
dart format --output=none --set-exit-if-changed lib
flutter analyze
```

## Licence

Projet academique PFE - L3-ISIL, Ecole Superieure des Sciences et
Technologies (ESST).
