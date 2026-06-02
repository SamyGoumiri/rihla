import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:rihla/core/services/connectivity_service.dart';
import 'package:rihla/core/services/guest_session_service.dart';
import 'package:rihla/core/services/pending_email_confirmation_store.dart';
import 'package:rihla/core/services/supabase_auth_service.dart';
import 'package:rihla/core/services/user_data_sync_service.dart';
import 'package:rihla/core/state/session_mode.dart';
import 'package:rihla/features/auth/presentation/reset_password_page.dart';
import 'package:rihla/features/navigation/presentation/app_shell.dart';
import 'package:rihla/features/navigation/presentation/auth_stack.dart';

typedef AppRouterShellBuilder =
    Widget Function({
      required bool isGuestMode,
      Future<void> Function()? onSignOut,
      Future<void> Function()? onManualSync,
      Future<void> Function()? onExitSession,
    });

class AppRouter extends StatefulWidget {
  const AppRouter({
    super.key,
    SupabaseAuthService? authService,
    UserDataSyncService? syncService,
    ConnectivityService? connectivityService,
    Stream<String?>? authStateChanges,
    Stream<void>? passwordRecoveryEvents,
    this.initialUid,
    this.appShellBuilder,
    this.passwordRecoveryPageBuilder,
  }) : _authService = authService,
       _syncService = syncService,
       _connectivityService = connectivityService,
       _authStateChanges = authStateChanges,
       _passwordRecoveryEvents = passwordRecoveryEvents;

  final SupabaseAuthService? _authService;
  final UserDataSyncService? _syncService;
  final ConnectivityService? _connectivityService;
  final Stream<String?>? _authStateChanges;
  final Stream<void>? _passwordRecoveryEvents;
  final String? initialUid;
  final AppRouterShellBuilder? appShellBuilder;
  final WidgetBuilder? passwordRecoveryPageBuilder;

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> with WidgetsBindingObserver {
  SupabaseAuthService? _authService;
  late final UserDataSyncService _syncService =
      widget._syncService ?? UserDataSyncService();
  late final ConnectivityService _connectivityService =
      widget._connectivityService ?? ConnectivityService();

  StreamSubscription<String?>? _authSubscription;
  StreamSubscription<void>? _passwordRecoverySubscription;
  StreamSubscription<bool>? _connectivitySubscription;
  bool _isReady = true;
  bool _isSyncing = false;
  bool _isPasswordRecoveryOpen = false;
  bool _guestSessionPendingAuthMigration = false;

  bool _justConfirmedSignup = false;

  bool _isHandlingSignupConfirmation = false;
  String? _activeUid;
  String? _currentUid;
  late bool _isGuestMode;

  String _authStackInitialRoute = AuthStack.welcomeRoute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authService =
        widget._authService ??
        (widget._authStateChanges == null ? SupabaseAuthService() : null);
    _currentUid = widget.initialUid ?? _authService?.currentUid;
    if (_currentUid != null &&
        GuestSessionService.currentGuestIdOrNull()?.isNotEmpty == true) {
      unawaited(GuestSessionService.clearActiveSession());
    }
    _isGuestMode =
        _currentUid == null &&
        GuestSessionService.currentGuestIdOrNull()?.isNotEmpty == true;
    _publishSessionMode();
    final authStateChanges =
        widget._authStateChanges ?? _authService?.authStateChanges();
    _authSubscription = authStateChanges?.listen(_onAuthChanged);
    final passwordRecoveryEvents =
        widget._passwordRecoveryEvents ??
        _authService?.passwordRecoveryEvents();
    _passwordRecoverySubscription = passwordRecoveryEvents?.listen((_) {
      unawaited(_showPasswordRecoveryPage());
    });

    _connectivitySubscription = _connectivityService.isOnlineStream.listen((
      isOnline,
    ) {
      if (isOnline && _activeUid != null) {
        unawaited(_syncService.onConnectivityRestored());
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _activeUid != null) {
      unawaited(_syncService.onAppResumed());
    }
  }

  Future<void> _showPasswordRecoveryPage() async {
    if (!mounted || _isPasswordRecoveryOpen) {
      return;
    }
    _isPasswordRecoveryOpen = true;
    final pageBuilder = widget.passwordRecoveryPageBuilder;
    final page = pageBuilder == null
        ? ResetPasswordPage(authService: _authService)
        : Builder(builder: pageBuilder);
    try {
      await Navigator.of(context, rootNavigator: true).push<bool>(
        MaterialPageRoute<bool>(fullscreenDialog: true, builder: (_) => page),
      );
    } finally {
      _isPasswordRecoveryOpen = false;
    }
  }

  void _publishSessionMode() {
    if (_currentUid != null) {
      SessionModeNotifier.setAuthenticated();
    } else if (_isGuestMode) {
      SessionModeNotifier.setGuest();
    } else {
      SessionModeNotifier.setNone();
    }
  }

  Future<void> _onAuthChanged(String? uid) async {
    if (!mounted) {
      return;
    }

    if (uid != null && _currentUid == null && !_isHandlingSignupConfirmation) {
      final pendingEmail = await PendingEmailConfirmationStore.read();
      if (!mounted) return;
      if (pendingEmail != null) {
        final confirmedEmail = _authService?.currentEmail?.trim().toLowerCase();
        final isSignupConfirmation =
            confirmedEmail == null ||
            confirmedEmail == pendingEmail.toLowerCase();
        await PendingEmailConfirmationStore.clear();
        if (isSignupConfirmation) {
          _isHandlingSignupConfirmation = true;
          await _authService?.signOut();
          if (!mounted) {
            _isHandlingSignupConfirmation = false;
            return;
          }
          setState(() {
            _justConfirmedSignup = true;
            _currentUid = null;
            _activeUid = null;
            _isGuestMode = false;
            _isReady = true;
          });
          _publishSessionMode();
          _isHandlingSignupConfirmation = false;
          return;
        }
      }
    }

    final previousUid = _currentUid;
    final previousGuestMode = _isGuestMode;
    final pendingGuestMigration = _guestSessionPendingAuthMigration;
    final guestIdForMigration =
        uid != null &&
            previousUid == null &&
            (previousGuestMode || pendingGuestMigration)
        ? GuestSessionService.consumePendingMigrationGuestId() ??
              GuestSessionService.currentGuestIdOrNull()
        : null;

    setState(() {
      _currentUid = uid;
      _isReady = true;
      if (uid != null) {
        _isGuestMode = false;

        _justConfirmedSignup = false;
      } else {
        _isGuestMode =
            GuestSessionService.currentGuestIdOrNull()?.isNotEmpty == true;
        if (previousUid != null) {
          _authStackInitialRoute = AuthStack.welcomeRoute;
        }
      }
    });
    _publishSessionMode();

    if (uid == _activeUid) {
      return;
    }

    if (uid == null) {
      if (_activeUid != null) {
        await _syncService.syncOnLogout(_activeUid!);
      }
      _activeUid = null;
      return;
    }

    if (_isSyncing) {
      return;
    }

    _activeUid = uid;
    _isSyncing = true;
    try {
      if (guestIdForMigration != null && guestIdForMigration.isNotEmpty) {
        await _syncService.migrateGuestState(guestIdForMigration, uid);
      }
      await _syncService.syncOnLogin(uid);
      if ((guestIdForMigration != null && guestIdForMigration.isNotEmpty) ||
          GuestSessionService.currentGuestIdOrNull()?.isNotEmpty == true) {
        await GuestSessionService.clearActiveSession();
      }
    } finally {
      _guestSessionPendingAuthMigration = false;
      _isSyncing = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _passwordRecoverySubscription?.cancel();
    _connectivitySubscription?.cancel();
    _syncService.stopRealtimeSync();
    super.dispose();
  }

  Future<void> _signOut() async {
    final activeUid = _activeUid;
    if (activeUid != null) {
      try {
        await _syncService.pushPending(activeUid);
      } catch (e) {
        developer.log(
          '_signOut: pushPending pré-signOut a échoué — on continue '
          'la déconnexion: $e',
          level: 800,
        );
      }
    }

    await GuestSessionService.clearActiveSession();
    await _authService?.signOut();
  }

  Future<void> _manualSync() async {
    await _syncService.syncActiveUserNow();
  }

  Future<void> _enterGuestMode() async {
    await GuestSessionService.ensureActiveSession();
    if (!mounted) {
      return;
    }

    setState(() {
      _guestSessionPendingAuthMigration = false;
      _isGuestMode = true;
      _justConfirmedSignup = false;
    });
    _publishSessionMode();
  }

  Future<void> _exitGuestMode() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _guestSessionPendingAuthMigration =
          GuestSessionService.currentGuestIdOrNull()?.isNotEmpty == true;
      _isGuestMode = false;

      _authStackInitialRoute = AuthStack.loginRoute;
    });
    _publishSessionMode();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_currentUid == null) {
      if (_justConfirmedSignup) {
        return AuthStack(
          key: const ValueKey<String>('auth-stack-account-confirmed'),
          onContinueAsGuest: _enterGuestMode,
          initialRoute: AuthStack.accountConfirmedRoute,
        );
      }

      if (_isGuestMode) {
        return _buildShell(
          isGuestMode: true,
          onExitSession: _exitGuestMode,
          onManualSync: null,
          onSignOut: null,
        );
      }

      return AuthStack(
        key: ValueKey<String>('auth-stack-$_authStackInitialRoute'),
        onContinueAsGuest: _enterGuestMode,
        initialRoute: _authStackInitialRoute,
      );
    }

    return _buildShell(
      isGuestMode: false,
      onSignOut: _signOut,
      onManualSync: _manualSync,
    );
  }

  Widget _buildShell({
    required bool isGuestMode,
    Future<void> Function()? onSignOut,
    Future<void> Function()? onManualSync,
    Future<void> Function()? onExitSession,
  }) {
    final customBuilder = widget.appShellBuilder;
    if (customBuilder != null) {
      return customBuilder(
        isGuestMode: isGuestMode,
        onSignOut: onSignOut,
        onManualSync: onManualSync,
        onExitSession: onExitSession,
      );
    }

    return AppShell(
      isGuestMode: isGuestMode,
      onSignOut: onSignOut,
      onManualSync: onManualSync,
      onExitSession: onExitSession,
    );
  }
}
