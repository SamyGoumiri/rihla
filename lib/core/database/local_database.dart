import 'dart:async';
import 'dart:developer' as developer;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();

  static const int _schemaVersion = 9;

  static const String _dbFileName = 'rihla.db';

  Database? _db;
  Future<Database>? _opening;

  Future<Database> open() {
    final existing = _db;
    if (existing != null && existing.isOpen) {
      return Future.value(existing);
    }
    return _opening ??= _doOpen();
  }

  Future<Database> openForTesting({
    required String path,
    OpenDatabaseOptions? options,
  }) async {
    await _db?.close();
    final effective =
        options ??
        OpenDatabaseOptions(
          version: _schemaVersion,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        );
    final db = await databaseFactory.openDatabase(path, options: effective);
    _db = db;
    return db;
  }

  Future<void> close() async {
    final db = _db;
    if (db != null && db.isOpen) {
      await db.close();
    }
    _db = null;
    _opening = null;
  }

  Future<Database> _doOpen() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, _dbFileName);
    developer.log(
      'Opening local SQLite database at $dbPath',
      name: 'LocalDatabase',
    );
    final db = await openDatabase(
      dbPath,
      version: _schemaVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    _db = db;
    _opening = null;
    return db;
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    for (final stmt in _ddl) {
      batch.execute(stmt);
    }
    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int from, int to) async {
    if (from < 2) {
      await _upgradeToV2(db);
    }
    if (from < 3) {
      await _upgradeToV3(db);
    }
    if (from < 4) {
      await _upgradeToV4(db);
    }
    if (from < 5) {
      await _upgradeToV5(db);
    }
    if (from < 6) {
      await _upgradeToV6(db);
    }
    if (from < 7) {
      await _upgradeToV7(db);
    }
    if (from < 8) {
      await _upgradeToV8(db);
    }
    if (from < 9) {
      await _upgradeToV9(db);
    }
    developer.log(
      'Upgraded local database from $from to $to',
      name: 'LocalDatabase',
    );
  }

  Future<void> _upgradeToV2(Database db) async {
    await db.execute('PRAGMA foreign_keys = OFF');
    await db.transaction((txn) async {
      await txn.execute('''
        CREATE TABLE sites_v2 (
          id                          TEXT PRIMARY KEY,
          name                        TEXT NOT NULL,
          image_url                   TEXT,
          primary_category            TEXT NOT NULL,
          city                        TEXT NOT NULL,
          address                     TEXT,
          description                 TEXT NOT NULL,
          short_description           TEXT,
          historical_info             TEXT,
          estimated_visit_duration    TEXT NOT NULL,
          best_period                 TEXT NOT NULL,
          rating                      REAL NOT NULL,
          latitude                    REAL NOT NULL,
          longitude                   REAL NOT NULL
        )
      ''');
      await txn.execute('''
        INSERT INTO sites_v2 (
          id,
          name,
          image_url,
          primary_category,
          city,
          address,
          description,
          short_description,
          historical_info,
          estimated_visit_duration,
          best_period,
          rating,
          latitude,
          longitude
        )
        SELECT
          id,
          name,
          image_url,
          primary_category,
          city,
          address,
          description,
          short_description,
          historical_info,
          estimated_visit_duration,
          best_period,
          rating,
          latitude,
          longitude
        FROM sites
      ''');
      await txn.execute('DROP TABLE sites');
      await txn.execute('ALTER TABLE sites_v2 RENAME TO sites');
      await txn.execute('CREATE INDEX idx_sites_city ON sites (city)');
      await txn.execute(
        'CREATE INDEX idx_sites_primary_category ON sites (primary_category)',
      );
    });
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _upgradeToV3(Database db) async {
    final profilesTables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'profiles'",
    );
    if (profilesTables.isEmpty) {
      await db.execute('''
        CREATE TABLE profiles (
          id                       TEXT PRIMARY KEY,
          display_name             TEXT,
          photo_path               TEXT,
          photo_url                TEXT,
          theme_preference         TEXT,
          preferred_city           TEXT,
          notifications_enabled    INTEGER NOT NULL DEFAULT 1,
          location_enabled         INTEGER NOT NULL DEFAULT 0,
          marketing_enabled        INTEGER NOT NULL DEFAULT 0,
          dark_mode_enabled        INTEGER NOT NULL DEFAULT 0,
          last_sync                INTEGER,
          updated_at               INTEGER NOT NULL,
          dirty                    INTEGER NOT NULL DEFAULT 0
        )
      ''');
      return;
    }

    await db.execute('PRAGMA foreign_keys = OFF');
    await db.transaction((txn) async {
      await txn.execute('''
        CREATE TABLE profiles_v3 (
          id                       TEXT PRIMARY KEY,
          display_name             TEXT,
          photo_path               TEXT,
          photo_url                TEXT,
          theme_preference         TEXT,
          preferred_city           TEXT,
          notifications_enabled    INTEGER NOT NULL DEFAULT 1,
          location_enabled         INTEGER NOT NULL DEFAULT 0,
          marketing_enabled        INTEGER NOT NULL DEFAULT 0,
          dark_mode_enabled        INTEGER NOT NULL DEFAULT 0,
          last_sync                INTEGER,
          updated_at               INTEGER NOT NULL,
          dirty                    INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await txn.execute('''
        INSERT INTO profiles_v3 (
          id,
          display_name,
          photo_path,
          photo_url,
          theme_preference,
          preferred_city,
          notifications_enabled,
          location_enabled,
          marketing_enabled,
          dark_mode_enabled,
          last_sync,
          updated_at,
          dirty
        )
        SELECT
          id,
          display_name,
          photo_path,
          photo_url,
          theme_preference,
          preferred_city,
          notifications_enabled,
          location_enabled,
          marketing_enabled,
          dark_mode_enabled,
          last_sync,
          updated_at,
          dirty
        FROM profiles
      ''');
      await txn.execute('DROP TABLE profiles');
      await txn.execute('ALTER TABLE profiles_v3 RENAME TO profiles');
    });
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _upgradeToV4(Database db) async {
    final categoriesTables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'categories'",
    );
    if (categoriesTables.isEmpty) {
      await db.execute(_categoriesDdl);
      return;
    }

    await db.transaction((txn) async {
      await txn.execute('''
        CREATE TABLE categories_v4 (
          slug                TEXT PRIMARY KEY,
          label               TEXT NOT NULL,
          icon_key            TEXT,
          canonical_enum_name TEXT,
          display_order       INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await txn.execute('''
        INSERT INTO categories_v4 (
          slug,
          label,
          icon_key,
          canonical_enum_name,
          display_order
        )
        SELECT
          slug,
          label_fr,
          icon_key,
          canonical_enum_name,
          display_order
        FROM categories
      ''');
      await txn.execute('DROP TABLE categories');
      await txn.execute('ALTER TABLE categories_v4 RENAME TO categories');
    });
  }

  Future<void> _upgradeToV5(Database db) async {
    await db.execute('PRAGMA foreign_keys = OFF');
    await db.transaction((txn) async {
      await txn.execute('''
        CREATE TABLE sites_v5 (
          id                  TEXT PRIMARY KEY,
          name                TEXT NOT NULL,
          image_url           TEXT,
          primary_category    TEXT NOT NULL,
          city                TEXT NOT NULL,
          address             TEXT,
          description         TEXT NOT NULL,
          short_description   TEXT,
          historical_info     TEXT,
          rating              REAL NOT NULL,
          latitude            REAL NOT NULL,
          longitude           REAL NOT NULL
        )
      ''');
      await txn.execute('''
        INSERT INTO sites_v5 (
          id,
          name,
          image_url,
          primary_category,
          city,
          address,
          description,
          short_description,
          historical_info,
          rating,
          latitude,
          longitude
        )
        SELECT
          id,
          name,
          image_url,
          primary_category,
          city,
          address,
          description,
          short_description,
          historical_info,
          rating,
          latitude,
          longitude
        FROM sites
      ''');
      await txn.execute('DROP TABLE sites');
      await txn.execute('ALTER TABLE sites_v5 RENAME TO sites');
      await txn.execute('CREATE INDEX idx_sites_city ON sites (city)');
      await txn.execute(
        'CREATE INDEX idx_sites_primary_category ON sites (primary_category)',
      );
    });
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _upgradeToV6(Database db) async {
    final existing = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN ('reviews', 'ratings')",
    );
    final tables = existing.map((row) => row['name'] as String?).toSet();
    if (tables.contains('reviews')) {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_reviews_site_id ON reviews (site_id)',
      );
    }
    if (tables.contains('ratings')) {
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ratings_site_id ON ratings (site_id)',
      );
    }
  }

  Future<void> _upgradeToV7(Database db) async {
    final profilesTables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'profiles'",
    );
    if (profilesTables.isEmpty) return;

    await db.execute('PRAGMA foreign_keys = OFF');
    await db.transaction((txn) async {
      await txn.execute('''
        CREATE TABLE profiles_v7 (
          id                TEXT PRIMARY KEY,
          display_name      TEXT,
          photo_path        TEXT,
          photo_url         TEXT,
          theme_preference  TEXT,
          last_sync         INTEGER,
          updated_at        INTEGER NOT NULL,
          dirty             INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await txn.execute('''
        INSERT INTO profiles_v7 (
          id,
          display_name,
          photo_path,
          photo_url,
          theme_preference,
          last_sync,
          updated_at,
          dirty
        )
        SELECT
          id,
          display_name,
          photo_path,
          photo_url,
          theme_preference,
          last_sync,
          updated_at,
          dirty
        FROM profiles
      ''');
      await txn.execute('DROP TABLE profiles');
      await txn.execute('ALTER TABLE profiles_v7 RENAME TO profiles');
    });
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _upgradeToV8(Database db) async {
    await db.execute('DROP TABLE IF EXISTS itinerary_items');
  }

  Future<void> _upgradeToV9(Database db) async {
    final cols = await db.rawQuery('PRAGMA table_info(sites)');
    final hasColumn = cols.any((row) => row['name'] == 'gallery_urls');
    if (!hasColumn) {
      await db.execute('ALTER TABLE sites ADD COLUMN gallery_urls TEXT');
    }
  }

  static const String _categoriesDdl = '''
    CREATE TABLE categories (
      slug                TEXT PRIMARY KEY,
      label               TEXT NOT NULL,
      icon_key            TEXT,
      canonical_enum_name TEXT,
      display_order       INTEGER NOT NULL DEFAULT 0
    )
    ''';

  static const List<String> _ddl = <String>[
    _categoriesDdl,
    '''
    CREATE TABLE sites (
      id                  TEXT PRIMARY KEY,
      name                TEXT NOT NULL,
      image_url           TEXT,
      gallery_urls        TEXT,
      primary_category    TEXT NOT NULL,
      city                TEXT NOT NULL,
      address             TEXT,
      description         TEXT NOT NULL,
      short_description   TEXT,
      historical_info     TEXT,
      rating              REAL NOT NULL,
      latitude            REAL NOT NULL,
      longitude           REAL NOT NULL
    )
    ''',
    '''
    CREATE TABLE site_categories (
      site_id        TEXT NOT NULL,
      category_slug  TEXT NOT NULL,
      PRIMARY KEY (site_id, category_slug),
      FOREIGN KEY (site_id) REFERENCES sites(id) ON DELETE CASCADE,
      FOREIGN KEY (category_slug) REFERENCES categories(slug) ON DELETE RESTRICT
    )
    ''',
    'CREATE INDEX idx_sites_city ON sites (city)',
    'CREATE INDEX idx_sites_primary_category ON sites (primary_category)',
    'CREATE INDEX idx_site_categories_category ON site_categories (category_slug)',

    '''
    CREATE TABLE profiles (
      id                TEXT PRIMARY KEY,
      display_name      TEXT,
      photo_path        TEXT,
      photo_url         TEXT,
      theme_preference  TEXT,
      last_sync         INTEGER,
      updated_at        INTEGER NOT NULL,
      dirty             INTEGER NOT NULL DEFAULT 0
    )
    ''',

    '''
    CREATE TABLE favorites (
      user_id     TEXT NOT NULL,
      site_id     TEXT NOT NULL,
      created_at  INTEGER NOT NULL,
      dirty       INTEGER NOT NULL DEFAULT 0,
      deleted     INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (user_id, site_id)
    )
    ''',
    'CREATE INDEX idx_favorites_dirty ON favorites (user_id, dirty)',

    '''
    CREATE TABLE view_history (
      id          TEXT PRIMARY KEY,
      user_id     TEXT NOT NULL,
      site_id     TEXT NOT NULL,
      viewed_at   INTEGER NOT NULL,
      dirty       INTEGER NOT NULL DEFAULT 0,
      deleted     INTEGER NOT NULL DEFAULT 0
    )
    ''',
    'CREATE INDEX idx_view_history_user_viewed ON view_history (user_id, viewed_at DESC)',

    '''
    CREATE TABLE ratings (
      user_id     TEXT NOT NULL,
      site_id     TEXT NOT NULL,
      rating      INTEGER NOT NULL,
      updated_at  INTEGER NOT NULL,
      dirty       INTEGER NOT NULL DEFAULT 0,
      deleted     INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (user_id, site_id)
    )
    ''',
    'CREATE INDEX idx_ratings_site_id ON ratings (site_id)',
    '''
    CREATE TABLE reviews (
      user_id     TEXT NOT NULL,
      site_id     TEXT NOT NULL,
      rating      INTEGER NOT NULL,
      comment     TEXT,
      updated_at  INTEGER NOT NULL,
      dirty       INTEGER NOT NULL DEFAULT 0,
      deleted     INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (user_id, site_id)
    )
    ''',
    'CREATE INDEX idx_reviews_site_id ON reviews (site_id)',

    '''
    CREATE TABLE sync_state (
      key    TEXT PRIMARY KEY,
      value  TEXT
    )
    ''',
  ];
}
