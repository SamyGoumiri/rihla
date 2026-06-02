import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

class PendingEmailConfirmationStore {
  PendingEmailConfirmationStore._();

  static const String _key = 'pending_email_confirmation';

  static Future<void> write(String email) async {
    final normalized = email.trim();
    if (normalized.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, normalized);
    } on Object catch (e) {
      developer.log(
        'PendingEmailConfirmationStore.write failed: $e',
        level: 800,
      );
    }
  }

  static Future<String?> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_key)?.trim();
      return (value == null || value.isEmpty) ? null : value;
    } on Object catch (e) {
      developer.log(
        'PendingEmailConfirmationStore.read failed: $e',
        level: 800,
      );
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } on Object catch (e) {
      developer.log(
        'PendingEmailConfirmationStore.clear failed: $e',
        level: 800,
      );
    }
  }
}
