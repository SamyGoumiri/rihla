import 'dart:async';

import 'package:rihla/core/database/local_database.dart';
import 'package:rihla/core/services/auth_uid_resolver.dart';
import 'package:rihla/core/services/guest_session_service.dart';
import 'package:sqflite/sqflite.dart';

String _readString(dynamic value) => value is String ? value : '';

Map<dynamic, dynamic>? _readMap(dynamic value) {
  if (value is Map) return Map<dynamic, dynamic>.from(value);
  return null;
}

enum AppThemePreference {
  system,
  light,
  dark;

  String get storageKey {
    switch (this) {
      case AppThemePreference.system:
        return 'system';
      case AppThemePreference.light:
        return 'light';
      case AppThemePreference.dark:
        return 'dark';
    }
  }

  static AppThemePreference fromStorage(String? value) {
    switch (value) {
      case 'dark':
        return AppThemePreference.dark;
      case 'light':
        return AppThemePreference.light;
      case 'system':
      default:
        return AppThemePreference.system;
    }
  }
}

class ProfilePreferences {
  const ProfilePreferences({required this.themePreference});

  final AppThemePreference themePreference;

  ProfilePreferences copyWith({AppThemePreference? themePreference}) {
    return ProfilePreferences(
      themePreference: themePreference ?? this.themePreference,
    );
  }

  Map<String, dynamic> toJson() {
    return {'themePreference': themePreference.storageKey};
  }

  static ProfilePreferences fromJson(Map<String, dynamic> json) {
    final raw = json['themePreference'];
    final theme = raw is String
        ? AppThemePreference.fromStorage(raw)
        : AppThemePreference.system;
    return ProfilePreferences(themePreference: theme);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfilePreferences && other.themePreference == themePreference;

  @override
  int get hashCode => themePreference.hashCode;
}

class ProfileData {
  const ProfileData({
    required this.displayName,
    required this.photoPath,
    required this.preferences,
    this.photoUrl = '',
  });

  final String displayName;
  final String photoPath;
  final String photoUrl;
  final ProfilePreferences preferences;

  ProfileData copyWith({
    String? displayName,
    String? photoPath,
    String? photoUrl,
    ProfilePreferences? preferences,
  }) {
    return ProfileData(
      displayName: displayName ?? this.displayName,
      photoPath: photoPath ?? this.photoPath,
      photoUrl: photoUrl ?? this.photoUrl,
      preferences: preferences ?? this.preferences,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'displayName': displayName,
      'photoPath': photoPath,
      'photoUrl': photoUrl,
      'preferences': preferences.toJson(),
    };
  }

  Map<String, dynamic> toRemoteJson() {
    return {
      'displayName': displayName,
      'photoPath': '',
      'photoUrl': photoUrl,
      'preferences': preferences.toJson(),
    };
  }

  static ProfileData fromJson(Map<String, dynamic> json) {
    final preferences = _readMap(json['preferences']);

    return ProfileData(
      displayName: _readString(json['displayName']),
      photoPath: _readString(json['photoPath']),
      photoUrl: _readString(json['photoUrl']),
      preferences: ProfilePreferences.fromJson(
        preferences == null
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(preferences),
      ),
    );
  }
}

class ProfileService {
  static final StreamController<void> _changesController =
      StreamController<void>.broadcast();

  static Stream<void> get changes => _changesController.stream;

  static void notifyChanged() => _changesController.add(null);

  ProfileService({String? userIdOverride}) : _userIdOverride = userIdOverride;

  final String? _userIdOverride;

  String get _userId {
    if (_userIdOverride?.isNotEmpty == true) return _userIdOverride!;
    return resolveCurrentUid() ??
        GuestSessionService.currentGuestIdOrNull() ??
        'guest_uninitialized';
  }

  Future<Database> get _db => LocalDatabase.instance.open();

  static const _defaultPreferences = ProfilePreferences(
    themePreference: AppThemePreference.system,
  );

  static const _defaultProfile = ProfileData(
    displayName: '',
    photoPath: '',
    preferences: _defaultPreferences,
  );

  Future<ProfileData> getProfile() async {
    final db = await _db;
    final rows = await db.query(
      'profiles',
      where: 'id = ?',
      whereArgs: [_userId],
      limit: 1,
    );
    if (rows.isEmpty) return _defaultProfile;
    return _profileFromRow(rows.first);
  }

  Future<void> saveProfile(ProfileData data) async {
    final db = await _db;
    await db.insert('profiles', {
      'id': _userId,
      'display_name': data.displayName,
      'photo_path': data.photoPath,
      'photo_url': data.photoUrl,
      'theme_preference': data.preferences.themePreference.storageKey,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
      'dirty': 1,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    _changesController.add(null);
  }

  Future<void> replaceProfile(ProfileData data) async => saveProfile(data);

  ProfileData _profileFromRow(Map<String, dynamic> row) {
    return ProfileData(
      displayName: (row['display_name'] as String?) ?? '',
      photoPath: (row['photo_path'] as String?) ?? '',
      photoUrl: (row['photo_url'] as String?) ?? '',
      preferences: ProfilePreferences(
        themePreference: AppThemePreference.fromStorage(
          row['theme_preference'] as String?,
        ),
      ),
    );
  }
}
