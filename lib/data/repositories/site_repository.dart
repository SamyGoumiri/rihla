import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:rihla/core/database/local_database.dart';
import 'package:rihla/core/database/remote_database.dart';
import 'package:rihla/data/models/tourist_site.dart';
import 'package:sqflite/sqflite.dart';

enum SiteDataSourceStatus { cloud, empty, unavailable }

class SiteRepository {
  SiteRepository({
    LocalDatabase? localDb,
    RemoteDatabase? remoteDb,
    Duration cacheTtl = const Duration(minutes: 10),
  }) : _local = localDb ?? LocalDatabase.instance,
       _remote = remoteDb ?? SupabaseRemoteDatabase(),
       _cacheTtl = cacheTtl;

  static final SiteRepository instance = SiteRepository();
  static final ValueNotifier<SiteDataSourceStatus> dataSourceStatus =
      ValueNotifier<SiteDataSourceStatus>(SiteDataSourceStatus.cloud);
  static final ValueNotifier<bool> hasConnectionIssue = ValueNotifier<bool>(
    false,
  );

  final LocalDatabase _local;
  final RemoteDatabase _remote;
  final Duration _cacheTtl;

  List<TouristSite>? _cache;
  Map<String, TouristSite>? _indexById;
  DateTime? _cacheLoadedAt;

  bool _isCacheFresh() {
    if (_cache == null || _cacheLoadedAt == null) return false;
    return DateTime.now().difference(_cacheLoadedAt!) < _cacheTtl;
  }

  void _setCache(List<TouristSite> sites) {
    _cache = sites;
    _indexById = {for (final site in sites) site.id: site};
    _cacheLoadedAt = DateTime.now();
  }

  Future<List<TouristSite>> getSites({bool forceRefresh = false}) async {
    if (!forceRefresh && _isCacheFresh()) return _cache!;

    final db = await _local.open();

    if (!forceRefresh) {
      final fresh = await _isSqliteFresh(db);
      if (fresh) {
        final localSites = await _loadFromSqlite(db);
        if (localSites.isNotEmpty) {
          final ratings = await _fetchReviewAggregatesSafely();
          final enriched = _applyRatings(localSites, ratings);
          _setCache(enriched);
          dataSourceStatus.value = SiteDataSourceStatus.cloud;
          hasConnectionIssue.value = false;
          return enriched;
        }
      }
    }

    try {
      final rowsFuture = _remote.fetchSites();

      final ratingsFuture = _fetchReviewAggregatesSafely();
      final results = await Future.wait<Object>([rowsFuture, ratingsFuture]);
      final rows = results[0] as List<Map<String, dynamic>>;
      final ratings = results[1] as Map<String, _SiteRatingAggregate>;

      if (rows.isEmpty) {
        await _hydrateSqlite(db, []);
        _setCache([]);
        dataSourceStatus.value = SiteDataSourceStatus.empty;
        hasConnectionIssue.value = false;
        return [];
      }
      final sites =
          rows
              .map((row) => _siteFromRemote(row, ratings))
              .where(_isValidSite)
              .toList()
            ..sort((a, b) => a.name.compareTo(b.name));
      await _hydrateSqlite(db, rows);
      _setCache(sites);
      dataSourceStatus.value = SiteDataSourceStatus.cloud;
      hasConnectionIssue.value = false;
      return sites;
    } catch (e, st) {
      developer.log(
        'SiteRepository: remote fetch failed — serving stale SQLite data.',
        error: e,
        stackTrace: st,
        level: 900,
      );
      final staleSites = await _loadFromSqlite(db);
      if (staleSites.isNotEmpty) {
        final ratings = await _fetchReviewAggregatesSafely();
        final enriched = _applyRatings(staleSites, ratings);
        _setCache(enriched);
        hasConnectionIssue.value = true;
        dataSourceStatus.value = SiteDataSourceStatus.cloud;
        return enriched;
      }
      _setCache([]);
      dataSourceStatus.value = SiteDataSourceStatus.unavailable;
      hasConnectionIssue.value = true;
      return [];
    }
  }

  Future<TouristSite?> getSiteById(String id) async {
    if (!_isCacheFresh()) await getSites();
    return _indexById?[id];
  }

  void dispose() {}

  Future<bool> _isSqliteFresh(Database db) async {
    final rows = await db.query(
      'sync_state',
      where: 'key = ?',
      whereArgs: ['last_sync_sites'],
    );
    if (rows.isEmpty) return false;
    final ms = int.tryParse(rows.first['value'] as String? ?? '');
    if (ms == null) return false;
    return DateTime.now().millisecondsSinceEpoch - ms <
        _cacheTtl.inMilliseconds;
  }

  Future<List<TouristSite>> _loadFromSqlite(Database db) async {
    final rows = await db.rawQuery('''
      SELECT s.*,
             GROUP_CONCAT(sc.category_slug, ',') AS category_slugs
      FROM   sites s
      LEFT   JOIN site_categories sc ON sc.site_id = s.id
      GROUP  BY s.id
      ORDER  BY s.name
    ''');
    return rows.map(_siteFromSqlite).where(_isValidSite).toList();
  }

  Future<void> _hydrateSqlite(
    Database db,
    List<Map<String, dynamic>> remoteRows,
  ) async {
    await db.execute('PRAGMA foreign_keys = OFF');
    final batch = db.batch();
    batch.rawDelete('DELETE FROM site_categories');
    batch.rawDelete('DELETE FROM sites');
    for (final row in remoteRows) {
      final siteId = row['id'] as String;
      batch.insert(
        'sites',
        _sqliteRowFromRemote(row),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      final cats = row['site_categories'] as List<dynamic>? ?? [];
      for (final cat in cats) {
        final slug = (cat as Map<String, dynamic>)['category_slug'] as String?;
        if (slug != null && slug.isNotEmpty) {
          batch.insert('site_categories', {
            'site_id': siteId,
            'category_slug': slug,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    }
    await batch.commit(noResult: true);
    await db.execute('PRAGMA foreign_keys = ON');
    await db.insert('sync_state', {
      'key': 'last_sync_sites',
      'value': DateTime.now().millisecondsSinceEpoch.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Map<String, dynamic> _sqliteRowFromRemote(Map<String, dynamic> row) {
    return {
      'id': row['id'],
      'name': row['name'],
      'image_url': row['image_url'],
      'gallery_urls': _encodeGallery(row['gallery_urls']),
      'primary_category': row['primary_category'],
      'city': row['city'],
      'address': row['address'],
      'description': row['description'],
      'short_description': row['short_description'],
      'historical_info': row['historical_info'],
      'rating': row['rating'],
      'latitude': row['latitude'],
      'longitude': row['longitude'],
    };
  }

  static String? _encodeGallery(Object? raw) {
    if (raw == null) return null;
    if (raw is String) {
      final trimmed = raw.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (raw is List) {
      final filtered = raw
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (filtered.isEmpty) return null;
      return jsonEncode(filtered);
    }
    return null;
  }

  static List<String> _decodeGallery(Object? raw) {
    if (raw == null) return const <String>[];
    if (raw is List) {
      return raw
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return const <String>[];
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is List) {
          return decoded
              .whereType<String>()
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
        }
      } catch (_) {}
    }
    return const <String>[];
  }

  static TouristSite _siteFromRemote(
    Map<String, dynamic> row, [
    Map<String, _SiteRatingAggregate> ratings = const {},
  ]) {
    final cats = (row['site_categories'] as List<dynamic>? ?? [])
        .map((c) => (c as Map<String, dynamic>)['category_slug'] as String)
        .toSet();
    final id = row['id'] as String;
    final agg = ratings[id];
    return TouristSite.fromMap(id, {
      'name': row['name'],
      'imageUrl': row['image_url'],
      'galleryImageUrls': _decodeGallery(row['gallery_urls']),
      'category': row['primary_category'],
      'categories': cats.toList(),
      'city': row['city'],
      'address': row['address'] ?? '',
      'description': row['description'],
      'shortDescription': row['short_description'] ?? '',
      'historicalInfo': row['historical_info'] ?? '',
      'latitude': row['latitude'],
      'longitude': row['longitude'],
      if (agg != null) 'averageRating': agg.average,
      if (agg != null) 'reviewCount': agg.count,
    });
  }

  static TouristSite _siteFromSqlite(Map<String, dynamic> row) {
    final slugsRaw = row['category_slugs'] as String?;
    final cats = (slugsRaw != null && slugsRaw.isNotEmpty)
        ? slugsRaw.split(',').where((s) => s.isNotEmpty).toList()
        : <String>[];
    return TouristSite.fromMap(row['id'] as String, {
      'name': row['name'],
      'imageUrl': row['image_url'],
      'galleryImageUrls': _decodeGallery(row['gallery_urls']),
      'category': row['primary_category'],
      'categories': cats,
      'city': row['city'],
      'address': row['address'] ?? '',
      'description': row['description'],
      'shortDescription': row['short_description'] ?? '',
      'historicalInfo': row['historical_info'] ?? '',
      'latitude': row['latitude'],
      'longitude': row['longitude'],
    });
  }

  static List<TouristSite> _applyRatings(
    List<TouristSite> sites,
    Map<String, _SiteRatingAggregate> ratings,
  ) {
    if (ratings.isEmpty) return sites;
    return sites
        .map((site) {
          final agg = ratings[site.id];
          if (agg == null) return site;
          return site.copyWithRating(
            averageRating: agg.average,
            reviewCount: agg.count,
          );
        })
        .toList(growable: false);
  }

  static bool _isValidSite(TouristSite site) {
    if (site.id.isEmpty || site.name.isEmpty) return false;
    if (site.latitude < -90 || site.latitude > 90) return false;
    if (site.longitude < -180 || site.longitude > 180) return false;
    if (site.latitude == 0 && site.longitude == 0) return false;
    return true;
  }

  @visibleForTesting
  void debugClearCache() {
    _cache = null;
    _indexById = null;
    _cacheLoadedAt = null;
  }

  Future<Map<String, _SiteRatingAggregate>>
  _fetchReviewAggregatesSafely() async {
    try {
      final rows = await _remote.fetchReviewRatings();
      final byId = <String, List<num>>{};
      for (final row in rows) {
        final siteId = row['site_id'] as String?;
        final rating = row['rating'];
        if (siteId == null || siteId.isEmpty || rating is! num) continue;
        byId.putIfAbsent(siteId, () => <num>[]).add(rating);
      }
      return byId.map((id, values) {
        if (values.isEmpty) {
          return MapEntry(id, const _SiteRatingAggregate(average: 0, count: 0));
        }
        final sum = values.fold<num>(0, (acc, v) => acc + v);
        final avg = sum.toDouble() / values.length;
        return MapEntry(
          id,
          _SiteRatingAggregate(average: avg, count: values.length),
        );
      });
    } catch (e, st) {
      developer.log(
        'SiteRepository: review aggregates fetch failed — sites without rating.',
        error: e,
        stackTrace: st,
        level: 800,
      );
      return const <String, _SiteRatingAggregate>{};
    }
  }
}

class _SiteRatingAggregate {
  const _SiteRatingAggregate({required this.average, required this.count});
  final double average;
  final int count;
}
