import 'dart:async';

import 'package:rihla/core/database/local_database.dart';
import 'package:rihla/core/services/auth_uid_resolver.dart';
import 'package:rihla/core/services/guest_session_service.dart';
import 'package:sqflite/sqflite.dart';

class HistoryEntry {
  const HistoryEntry({required this.siteId, required this.viewedAt});

  final String siteId;
  final DateTime viewedAt;
}

class HistoryService {
  static final StreamController<void> _changesController =
      StreamController<void>.broadcast();

  static Stream<void> get changes => _changesController.stream;

  static void notifyChanged() => _changesController.add(null);

  HistoryService({String? userIdOverride}) : _userIdOverride = userIdOverride;

  final String? _userIdOverride;

  String get _userId {
    if (_userIdOverride?.isNotEmpty == true) return _userIdOverride!;
    return resolveCurrentUid() ??
        GuestSessionService.currentGuestIdOrNull() ??
        'guest_uninitialized';
  }

  Future<Database> get _db => LocalDatabase.instance.open();

  String _rowId(String siteId) => '${_userId}_$siteId';

  Future<List<HistoryEntry>> getHistory() async {
    final db = await _db;
    final rows = await db.query(
      'view_history',
      where: 'user_id = ? AND deleted = 0',
      whereArgs: [_userId],
      orderBy: 'viewed_at DESC',
      limit: 1000,
    );
    return rows
        .map(
          (r) => HistoryEntry(
            siteId: r['site_id'] as String,
            viewedAt: DateTime.fromMillisecondsSinceEpoch(
              r['viewed_at'] as int,
            ),
          ),
        )
        .toList();
  }

  Future<void> recordVisit(String siteId) async {
    if (siteId.isEmpty) return;
    final db = await _db;
    await db.insert('view_history', {
      'id': _rowId(siteId),
      'user_id': _userId,
      'site_id': siteId,
      'viewed_at': DateTime.now().millisecondsSinceEpoch,
      'dirty': 1,
      'deleted': 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _changesController.add(null);
  }

  Future<List<String>> getRecentSiteIds({int limit = 5}) async {
    final history = await getHistory();
    return history.take(limit).map((e) => e.siteId).toList();
  }

  Future<int> getHistoryCount() async {
    final history = await getHistory();
    return history.length;
  }

  Future<void> setHistory(List<HistoryEntry> entries) async {
    final db = await _db;
    final batch = db.batch();
    batch.update(
      'view_history',
      {'deleted': 1, 'dirty': 1},
      where: 'user_id = ?',
      whereArgs: [_userId],
    );
    for (final entry in entries) {
      if (entry.siteId.isEmpty) continue;
      batch.insert('view_history', {
        'id': _rowId(entry.siteId),
        'user_id': _userId,
        'site_id': entry.siteId,
        'viewed_at': entry.viewedAt.millisecondsSinceEpoch,
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
      'view_history',
      {'deleted': 1, 'dirty': 1},
      where: 'user_id = ?',
      whereArgs: [_userId],
    );
    _changesController.add(null);
  }
}
