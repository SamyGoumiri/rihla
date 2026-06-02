import 'package:flutter/foundation.dart';

enum SessionMode { none, guest, authenticated }

class SessionModeNotifier {
  SessionModeNotifier._();

  static final ValueNotifier<SessionMode> mode = ValueNotifier<SessionMode>(
    SessionMode.none,
  );

  static bool get isGuest => mode.value == SessionMode.guest;

  static bool get isAuthenticated => mode.value == SessionMode.authenticated;

  static void setAuthenticated() {
    mode.value = SessionMode.authenticated;
  }

  static void setGuest() {
    mode.value = SessionMode.guest;
  }

  static void setNone() {
    mode.value = SessionMode.none;
  }

  @visibleForTesting
  static void debugReset() {
    mode.value = SessionMode.none;
  }
}
