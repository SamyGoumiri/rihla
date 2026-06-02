import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:rihla/core/database/local_database.dart';
import 'package:rihla/core/database/remote_database.dart';
import 'package:rihla/core/services/favorites_service.dart';
import 'package:rihla/core/services/history_service.dart';
import 'package:rihla/core/services/profile_service.dart';
import 'package:rihla/core/services/rating_service.dart';
import 'package:sqflite/sqflite.dart';

enum UserSyncState { idle, syncing, error }

class UserDataSyncService {
  UserDataSyncService({
    RemoteDatabase? remoteDb,
    ProfileService? profileService,
  }) : _remoteDb = remoteDb ?? SupabaseRemoteDatabase(),
       _profileService = profileService ?? ProfileService();

  final RemoteDatabase _remoteDb;

  final ProfileService _profileService;

  static final ValueNotifier<UserSyncState> syncState =
      ValueNotifier<UserSyncState>(UserSyncState.idle);
  static final ValueNotifier<DateTime?> lastSyncedAt = ValueNotifier<DateTime?>(
    null,
  );
  static final ValueNotifier<String?> lastSyncError = ValueNotifier<String?>(
    null,
  );

  StreamSubscription<void>? _favoritesSubscription;
  StreamSubscription<void>? _historySubscription;
  StreamSubscription<void>? _profileSubscription;
  StreamSubscription<void>? _ratingSubscription;
  Timer? _pendingPushTimer;

  String? _activeUid;
  String? get activeUid => _activeUid;

  Future<void> syncOnLogin(String uid) async {
    _setSyncing();
    try {
      _activeUid = uid;
      final pushSucceeded = await pushPending(uid);
      if (!pushSucceeded) {
        throw StateError(
          'Push des changements locaux en attente impossible. '
          'Pull distant annulé pour protéger les données offline.',
        );
      }
      await _pullRemote(uid);
      _startLocalChangeListeners(uid);
      _markSyncSuccess();
    } catch (e) {
      _setSyncError('Sync login failed: $e');
      rethrow;
    }
  }

  Future<void> syncActiveUserNow() async {
    final uid = _activeUid;
    if (uid == null || uid.isEmpty) {
      _setSyncError(
        'Aucun utilisateur actif pour la synchronisation manuelle.',
      );
      return;
    }
    _setSyncing();
    try {
      final pushSucceeded = await pushPending(uid);
      if (!pushSucceeded) {
        throw StateError(
          'Push des changements locaux en attente impossible. '
          'Pull distant annulé pour protéger les données offline.',
        );
      }
      await _pullRemote(uid);
      _markSyncSuccess();
    } catch (e) {
      _setSyncError('Manual sync failed: $e');
      rethrow;
    }
  }

  Future<void> syncOnLogout(String uid) async {
    try {
      await pushPending(uid);
    } catch (e) {
      developer.log(
        'syncOnLogout: pushPending échoué (données locales conservées): $e',
        level: 900,
      );
    }
    await stopRealtimeSync();
    _setIdle();
    developer.log(
      'User $uid logged out (données locales conservées pour survivre '
      'aux échecs de push réseau).',
      level: 800,
    );
  }

  Future<void> stopRealtimeSync() async {
    _pendingPushTimer?.cancel();
    _pendingPushTimer = null;
    await _favoritesSubscription?.cancel();
    await _historySubscription?.cancel();
    await _profileSubscription?.cancel();
    await _ratingSubscription?.cancel();
    _favoritesSubscription = null;
    _historySubscription = null;
    _profileSubscription = null;
    _ratingSubscription = null;
    _activeUid = null;
  }

  Future<void> onConnectivityRestored() async {
    final uid = _activeUid;
    if (uid == null) return;
    final pushSucceeded = await pushPending(uid);
    if (!pushSucceeded) {
      _setSyncError(
        'Synchronisation en attente : les données locales seront conservées.',
      );
    }
  }

  Future<void> onAppResumed() async {
    final uid = _activeUid;
    if (uid == null) return;
    try {
      final pushed = await pushPending(uid);
      if (!pushed) {
        developer.log(
          'onAppResumed: push impossible, pull annulé pour préserver '
          'les changements locaux dirty=1.',
          level: 800,
        );
        return;
      }
      await _pullRemote(uid);
      _markSyncSuccess();
    } catch (e) {
      developer.log('onAppResumed pull failed: $e', level: 800);
    }
  }

  Future<bool> pushPending([String? uid]) async {
    final targetUid = uid ?? _activeUid;
    if (targetUid == null || targetUid.isEmpty) return true;
    try {
      final db = await LocalDatabase.instance.open();
      await _pushFavorites(db, targetUid);
      await _pushViewHistory(db, targetUid);
      await _pushRatings(db, targetUid);
      await _pushReviews(db, targetUid);
      await _pushProfile(db, targetUid);
      return true;
    } catch (e) {
      developer.log('pushPending failed: $e', level: 900);
      return false;
    }
  }

  Future<void> migrateGuestState(String guestId, String uid) async {
    if (guestId.isEmpty || uid.isEmpty || guestId == uid) return;

    final guestProfile = ProfileService(userIdOverride: guestId);
    final guestProfData = await guestProfile.getProfile();

    const defaultPrefs = ProfilePreferences(
      themePreference: AppThemePreference.system,
    );
    if (guestProfData.preferences == defaultPrefs) return;

    final userProfData = await _profileService.getProfile();
    await _profileService.replaceProfile(
      userProfData.copyWith(preferences: guestProfData.preferences),
    );
  }

  Future<void> _pushFavorites(Database db, String uid) async {
    final dirty = await db.query(
      'favorites',
      where: 'user_id = ? AND dirty = 1',
      whereArgs: [uid],
    );
    if (dirty.isEmpty) return;
    final toUpsert = dirty
        .where((r) => (r['deleted'] as int) == 0)
        .map(
          (r) => {
            'user_id': r['user_id'],
            'site_id': r['site_id'],
            'created_at': _msToIso(r['created_at'] as int),
          },
        )
        .toList();
    final toDelete = dirty
        .where((r) => (r['deleted'] as int) == 1)
        .map((r) => {'user_id': r['user_id'], 'site_id': r['site_id']})
        .toList();
    if (toUpsert.isNotEmpty) await _remoteDb.upsertFavorites(toUpsert);
    if (toDelete.isNotEmpty) await _remoteDb.deleteFavorites(toDelete);
    await db.update(
      'favorites',
      {'dirty': 0},
      where: 'user_id = ? AND dirty = 1',
      whereArgs: [uid],
    );
  }

  Future<void> _pushViewHistory(Database db, String uid) async {
    final dirty = await db.query(
      'view_history',
      where: 'user_id = ? AND dirty = 1',
      whereArgs: [uid],
    );
    if (dirty.isEmpty) return;

    await _remoteDb.deleteAllViewHistoryForUser(uid);
    final allActive = await db.query(
      'view_history',
      where: 'user_id = ? AND deleted = 0',
      whereArgs: [uid],
    );
    final toInsert = allActive
        .map(
          (r) => {
            'user_id': r['user_id'],
            'site_id': r['site_id'],
            'viewed_at': _msToIso(r['viewed_at'] as int),
          },
        )
        .toList();
    await _remoteDb.upsertViewHistory(toInsert);
    await db.update(
      'view_history',
      {'dirty': 0},
      where: 'user_id = ? AND dirty = 1',
      whereArgs: [uid],
    );
  }

  Future<void> _pushRatings(Database db, String uid) async {
    final dirty = await db.query(
      'ratings',
      where: 'user_id = ? AND dirty = 1',
      whereArgs: [uid],
    );
    if (dirty.isEmpty) return;
    final toUpsert = dirty
        .where((r) => (r['deleted'] as int) == 0)
        .map(
          (r) => {
            'user_id': r['user_id'],
            'site_id': r['site_id'],
            'rating': r['rating'],
            'updated_at': _msToIso(r['updated_at'] as int),
          },
        )
        .toList();
    final toDelete = dirty
        .where((r) => (r['deleted'] as int) == 1)
        .map((r) => {'user_id': r['user_id'], 'site_id': r['site_id']})
        .toList();
    if (toUpsert.isNotEmpty) await _remoteDb.upsertRatings(toUpsert);
    if (toDelete.isNotEmpty) await _remoteDb.deleteRatings(toDelete);
    await db.update(
      'ratings',
      {'dirty': 0},
      where: 'user_id = ? AND dirty = 1',
      whereArgs: [uid],
    );
  }

  Future<void> _pushReviews(Database db, String uid) async {
    final dirty = await db.query(
      'reviews',
      where: 'user_id = ? AND dirty = 1',
      whereArgs: [uid],
    );
    if (dirty.isEmpty) return;
    final toUpsert = dirty
        .where((r) => (r['deleted'] as int) == 0)
        .map(
          (r) => {
            'user_id': r['user_id'],
            'site_id': r['site_id'],
            'rating': r['rating'],
            'comment': (r['comment'] as String?) ?? '',
            'updated_at': _msToIso(r['updated_at'] as int),
          },
        )
        .toList();
    final toDelete = dirty
        .where((r) => (r['deleted'] as int) == 1)
        .map((r) => {'user_id': r['user_id'], 'site_id': r['site_id']})
        .toList();
    if (toUpsert.isNotEmpty) await _remoteDb.upsertReviews(toUpsert);
    if (toDelete.isNotEmpty) await _remoteDb.deleteReviews(toDelete);
    await db.update(
      'reviews',
      {'dirty': 0},
      where: 'user_id = ? AND dirty = 1',
      whereArgs: [uid],
    );
  }

  Future<void> _pushProfile(Database db, String uid) async {
    final dirty = await db.query(
      'profiles',
      where: 'id = ? AND dirty = 1',
      whereArgs: [uid],
    );
    if (dirty.isEmpty) return;
    final row = dirty.first;
    await _remoteDb.upsertProfile({
      'id': row['id'],
      'display_name': row['display_name'],
      'photo_url': row['photo_url'],
      'theme_preference': row['theme_preference'],
      'updated_at': _msToIso(row['updated_at'] as int),
    });
    await db.update(
      'profiles',
      {'dirty': 0},
      where: 'id = ? AND dirty = 1',
      whereArgs: [uid],
    );
  }

  Future<void> _pullRemote(String uid) async {
    final snapshot = await _remoteDb.fetchUserData(uid);
    final db = await LocalDatabase.instance.open();
    final now = DateTime.now().millisecondsSinceEpoch;

    final localProfileRows = await db.query(
      'profiles',
      where: 'id = ?',
      whereArgs: [uid],
      limit: 1,
    );
    final localPhotoPath = localProfileRows.isEmpty
        ? ''
        : (localProfileRows.first['photo_path'] as String?) ?? '';

    final batch = db.batch();

    batch.delete(
      'favorites',
      where: 'user_id = ? AND dirty = 0',
      whereArgs: [uid],
    );
    for (final row in snapshot.favorites) {
      final siteId = row['site_id'] as String?;
      if (siteId == null || siteId.isEmpty) continue;
      batch.insert('favorites', {
        'user_id': uid,
        'site_id': siteId,
        'created_at': _isoToMs(row['created_at']) ?? now,
        'dirty': 0,
        'deleted': 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    batch.delete(
      'view_history',
      where: 'user_id = ? AND dirty = 0',
      whereArgs: [uid],
    );
    final seenSites = <String>{};
    for (final row in snapshot.viewHistory) {
      final siteId = row['site_id'] as String?;
      if (siteId == null || siteId.isEmpty || !seenSites.add(siteId)) continue;
      batch.insert('view_history', {
        'id': '${uid}_$siteId',
        'user_id': uid,
        'site_id': siteId,
        'viewed_at': _isoToMs(row['viewed_at']) ?? now,
        'dirty': 0,
        'deleted': 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    batch.delete(
      'ratings',
      where: 'user_id = ? AND dirty = 0',
      whereArgs: [uid],
    );
    for (final row in snapshot.ratings) {
      final siteId = row['site_id'] as String?;
      if (siteId == null || siteId.isEmpty) continue;
      batch.insert('ratings', {
        'user_id': uid,
        'site_id': siteId,
        'rating': row['rating'],
        'updated_at': _isoToMs(row['updated_at']) ?? now,
        'dirty': 0,
        'deleted': 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    batch.delete(
      'reviews',
      where: 'user_id = ? AND dirty = 0',
      whereArgs: [uid],
    );
    for (final row in snapshot.reviews) {
      final siteId = row['site_id'] as String?;
      if (siteId == null || siteId.isEmpty) continue;
      batch.insert('reviews', {
        'user_id': uid,
        'site_id': siteId,
        'rating': row['rating'],
        'comment': (row['comment'] as String?) ?? '',
        'updated_at': _isoToMs(row['updated_at']) ?? now,
        'dirty': 0,
        'deleted': 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    final remoteProfile = snapshot.profile;
    if (remoteProfile != null) {
      batch.insert('profiles', {
        'id': uid,
        'display_name': (remoteProfile['display_name'] as String?) ?? '',
        'photo_path': localPhotoPath,
        'photo_url': (remoteProfile['photo_url'] as String?) ?? '',
        'theme_preference':
            (remoteProfile['theme_preference'] as String?) ?? 'system',
        'updated_at': _isoToMs(remoteProfile['updated_at']) ?? now,
        'dirty': 0,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    await batch.commit(noResult: true);

    await db.insert('sync_state', {
      'key': 'last_sync_at',
      'value': now.toString(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    FavoritesService.notifyChanged();
    HistoryService.notifyChanged();
    ProfileService.notifyChanged();
    RatingService.notifyChanged();
  }

  void _startLocalChangeListeners(String uid) {
    _favoritesSubscription?.cancel();
    _historySubscription?.cancel();
    _profileSubscription?.cancel();
    _ratingSubscription?.cancel();

    _favoritesSubscription = FavoritesService.changes.listen(
      (_) => _schedulePush(uid),
    );
    _historySubscription = HistoryService.changes.listen(
      (_) => _schedulePush(uid),
    );
    _profileSubscription = ProfileService.changes.listen(
      (_) => _schedulePush(uid),
    );
    _ratingSubscription = RatingService.changes.listen(
      (_) => _schedulePush(uid),
    );
  }

  void _schedulePush(String uid) {
    _pendingPushTimer?.cancel();
    _pendingPushTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(pushPending(uid));
    });
  }

  void _setSyncing() {
    syncState.value = UserSyncState.syncing;
    lastSyncError.value = null;
  }

  void _markSyncSuccess() {
    lastSyncedAt.value = DateTime.now();
    _setIdle();
  }

  void _setIdle() {
    syncState.value = UserSyncState.idle;
    lastSyncError.value = null;
  }

  void _setSyncError(String message) {
    syncState.value = UserSyncState.error;
    lastSyncError.value = message;
  }

  static String _msToIso(int ms) =>
      DateTime.fromMillisecondsSinceEpoch(ms).toUtc().toIso8601String();

  static int? _isoToMs(dynamic value) {
    if (value is int) return value;
    if (value is String) {
      final dt = DateTime.tryParse(value);
      if (dt != null) return dt.millisecondsSinceEpoch;
    }
    return null;
  }
}
