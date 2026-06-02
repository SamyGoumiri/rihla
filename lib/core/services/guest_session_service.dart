import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GuestSessionService {
  GuestSessionService._();

  static const String _activeGuestIdKey = 'active_guest_session_id';
  static const String _installGuestIdKey = 'guest_install_id';

  static String? _activeGuestId;
  static String? _pendingMigrationGuestId;

  static Future<void> initialize() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _activeGuestId = prefs.getString(_activeGuestIdKey);
    _pendingMigrationGuestId = null;
  }

  static Future<String> startFreshSession() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String installId =
        prefs.getString(_installGuestIdKey) ?? _generateInstallId();
    await prefs.setString(_installGuestIdKey, installId);

    final String guestId =
        'guest_${installId}_${DateTime.now().microsecondsSinceEpoch}';
    _activeGuestId = guestId;
    await prefs.setString(_activeGuestIdKey, guestId);
    return guestId;
  }

  static Future<String> ensureActiveSession() async {
    final String? currentGuestId = _activeGuestId;
    if (currentGuestId != null && currentGuestId.isNotEmpty) {
      return currentGuestId;
    }

    return startFreshSession();
  }

  static Future<void> clearActiveSession() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _activeGuestId = null;
    _pendingMigrationGuestId = null;
    await prefs.remove(_activeGuestIdKey);
  }

  static String? currentGuestIdOrNull() => _activeGuestId;

  static String? captureActiveSessionForMigration() {
    final String? guestId = _activeGuestId;
    if (guestId == null || guestId.isEmpty) {
      return null;
    }

    _pendingMigrationGuestId = guestId;
    return guestId;
  }

  static String? consumePendingMigrationGuestId() {
    final String? guestId = _pendingMigrationGuestId;
    _pendingMigrationGuestId = null;
    return guestId;
  }

  @visibleForTesting
  static void debugReset() {
    _activeGuestId = null;
    _pendingMigrationGuestId = null;
  }

  static String _generateInstallId() {
    const String chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final Random random = Random.secure();
    return List<String>.generate(
      16,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }
}
