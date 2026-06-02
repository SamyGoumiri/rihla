import 'dart:async';

import 'package:rihla/core/database/local_database.dart';
import 'package:rihla/core/services/auth_uid_resolver.dart';
import 'package:rihla/core/services/guest_session_service.dart';
import 'package:sqflite/sqflite.dart';

class FavoritesService {
  static final StreamController<void> _changesController =
      StreamController<void>.broadcast();

  static Stream<void> get changes => _changesController.stream;

  static void notifyChanged() => _changesController.add(null);

  FavoritesService({String? userIdOverride}) : _userIdOverride = userIdOverride;

  final String? _userIdOverride;

  String get _userId {
    if (_userIdOverride?.isNotEmpty == true) return _userIdOverride!;
    return resolveCurrentUid() ??
        GuestSessionService.currentGuestIdOrNull() ??
        'guest_uninitialized';
  }

  Future<Database> get _db => LocalDatabase.instance.open();

  Future<List<String>> getFavorites() async {
    final db = await _db;
    final rows = await db.query(
      'favorites',
      columns: ['site_id'],
      where: 'user_id = ? AND deleted = 0',
      whereArgs: [_userId],
    );
    return rows.map((r) => r['site_id'] as String).toList();
  }

  Future<bool> isFavorite(String siteId) async {
    final db = await _db;
    final rows = await db.query(
      'favorites',
      columns: ['site_id'],
      where: 'user_id = ? AND site_id = ? AND deleted = 0',
      whereArgs: [_userId, siteId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> addFavorite(String siteId) async {
    if (siteId.isEmpty) return;
    final db = await _db;
    await db.insert('favorites', {
      'user_id': _userId,
      'site_id': siteId,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'dirty': 1,
      'deleted': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _changesController.add(null);
  }

  Future<void> removeFavorite(String siteId) async {
    final db = await _db;
    await db.update(
      'favorites',
      {'deleted': 1, 'dirty': 1},
      where: 'user_id = ? AND site_id = ?',
      whereArgs: [_userId, siteId],
    );
    _changesController.add(null);
  }

  Future<bool> toggleFavorite(String siteId) async {
    if (await isFavorite(siteId)) {
      await removeFavorite(siteId);
      return false;
    } else {
      await addFavorite(siteId);
      return true;
    }
  }

  Future<int> getFavoriteCount() async {
    final favs = await getFavorites();
    return favs.length;
  }

  Future<void> setFavorites(List<String> siteIds) async {
    final db = await _db;
    final unique = siteIds.where((id) => id.isNotEmpty).toList();
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = db.batch();
    batch.update(
      'favorites',
      {'deleted': 1, 'dirty': 1},
      where: 'user_id = ?',
      whereArgs: [_userId],
    );
    for (final id in unique) {
      batch.insert('favorites', {
        'user_id': _userId,
        'site_id': id,
        'created_at': now,
        'dirty': 0,
        'deleted': 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    _changesController.add(null);
  }

  Future<void> clearAll() async {
    final db = await _db;
    await db.update(
      'favorites',
      {'deleted': 1, 'dirty': 1},
      where: 'user_id = ?',
      whereArgs: [_userId],
    );
    _changesController.add(null);
  }
}
