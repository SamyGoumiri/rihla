import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rihla/core/services/profile_service.dart';
import 'package:rihla/core/theme/app_theme.dart';
import 'package:rihla/features/navigation/presentation/app_router.dart';

class PfeApp extends StatefulWidget {
  const PfeApp({
    super.key,
    ProfileService? profileService,
    this.appRouterBuilder,
  }) : _profileService = profileService;

  final ProfileService? _profileService;
  final WidgetBuilder? appRouterBuilder;

  @override
  State<PfeApp> createState() => _PfeAppState();
}

class _PfeAppState extends State<PfeApp> {
  late final ProfileService _profileService =
      widget._profileService ?? ProfileService();
  StreamSubscription<void>? _profileSubscription;
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      unawaited(_syncFromProfile());
      _profileSubscription = ProfileService.changes.listen((_) {
        unawaited(_syncFromProfile());
      });
    });
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    super.dispose();
  }

  Future<void> _syncFromProfile() async {
    final ProfileData profile = await _profileService.getProfile();
    if (!mounted) {
      return;
    }

    final ThemeMode nextMode = _resolveThemeMode(
      profile.preferences.themePreference,
    );
    if (nextMode == _themeMode) {
      return;
    }

    setState(() {
      _themeMode = nextMode;
    });
  }

  static ThemeMode _resolveThemeMode(AppThemePreference preference) {
    switch (preference) {
      case AppThemePreference.dark:
        return ThemeMode.dark;
      case AppThemePreference.light:
        return ThemeMode.light;
      case AppThemePreference.system:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    final routerBuilder = widget.appRouterBuilder;
    return MaterialApp(
      title: 'Rihla',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _themeMode,
      home: routerBuilder == null
          ? const AppRouter()
          : Builder(builder: routerBuilder),
    );
  }
}
