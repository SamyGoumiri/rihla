import 'dart:async';
import 'dart:developer' as developer;

import 'package:rihla/core/services/auth_failure.dart';
import 'package:rihla/core/services/guest_session_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAuthService {
  SupabaseAuthService({GoTrueClient? auth}) : _injectedAuth = auth;

  final GoTrueClient? _injectedAuth;

  GoTrueClient? get _authOrNull {
    final injected = _injectedAuth;
    if (injected != null) return injected;
    try {
      return Supabase.instance.client.auth;
    } on Object {
      return null;
    }
  }

  GoTrueClient get _requireAuth {
    final auth = _authOrNull;
    if (auth == null) {
      throw const AuthFailure(
        code: 'supabase-not-configured',
        message:
            'Supabase n\'est pas configuré. Relancez avec '
            '--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...',
      );
    }
    return auth;
  }

  String? get currentUid => _authOrNull?.currentUser?.id;

  String? get currentEmail => _authOrNull?.currentUser?.email;

  String? get currentDisplayName {
    final user = _authOrNull?.currentUser;
    if (user == null) return null;
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final displayName = (metadata['display_name'] as String?)?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;

    final fullName = (metadata['full_name'] as String?)?.trim();
    if (fullName != null && fullName.isNotEmpty) return fullName;

    final firstName = (metadata['first_name'] as String?)?.trim() ?? '';
    final lastName = (metadata['last_name'] as String?)?.trim() ?? '';
    final composite = '$firstName $lastName'.trim();
    if (composite.isNotEmpty) return composite;

    final name = (metadata['name'] as String?)?.trim();
    if (name != null && name.isNotEmpty) return name;

    return null;
  }

  Stream<String?> authStateChanges() {
    final auth = _authOrNull;
    if (auth == null) {
      return const Stream<String?>.empty();
    }
    return auth.onAuthStateChange
        .map((data) => data.session?.user.id)
        .distinct();
  }

  Stream<void> passwordRecoveryEvents() {
    final auth = _authOrNull;
    if (auth == null) {
      return const Stream<void>.empty();
    }
    return auth.onAuthStateChange
        .where((data) => data.event == AuthChangeEvent.passwordRecovery)
        .map<void>((_) {});
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    GuestSessionService.captureActiveSessionForMigration();
    try {
      await _requireAuth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      throw _mapException(e);
    }
  }

  Future<void> createUserWithEmail({
    required String email,
    required String password,
    String? displayName,
    String? firstName,
    String? lastName,
  }) async {
    GuestSessionService.captureActiveSessionForMigration();
    final metadata = <String, dynamic>{
      if (displayName != null && displayName.trim().isNotEmpty)
        'display_name': displayName.trim(),
      if (firstName != null && firstName.trim().isNotEmpty)
        'first_name': firstName.trim(),
      if (lastName != null && lastName.trim().isNotEmpty)
        'last_name': lastName.trim(),
      if ((firstName ?? '').trim().isNotEmpty ||
          (lastName ?? '').trim().isNotEmpty)
        'full_name': '${(firstName ?? '').trim()} ${(lastName ?? '').trim()}'
            .trim(),
    };
    try {
      if (displayName != null && displayName.trim().isNotEmpty) {
        await ensureDisplayNameAvailable(displayName.trim());
      }
      await _requireAuth.signUp(
        email: email,
        password: password,
        emailRedirectTo: 'rihla://auth-callback',
        data: metadata.isEmpty ? null : metadata,
      );
    } on AuthException catch (e) {
      throw _mapException(e);
    }
  }

  Future<void> ensureDisplayNameAvailable(
    String displayName, {
    String? excludingUserId,
  }) async {
    final normalized = displayName.trim();
    if (normalized.length < 4) {
      throw const AuthFailure(
        code: 'invalid-display-name',
        message: 'Le pseudo doit contenir au moins 4 caractères.',
      );
    }
    if (normalized.length > 16) {
      throw const AuthFailure(
        code: 'invalid-display-name',
        message: 'Le pseudo doit contenir au maximum 16 caractères.',
      );
    }
    try {
      final params = <String, dynamic>{'candidate': normalized};
      if (excludingUserId != null) {
        params['excluding_user_id'] = excludingUserId;
      }
      final available = await Supabase.instance.client.rpc<bool>(
        'is_display_name_available',
        params: params,
      );
      if (!available) {
        throw const AuthFailure(
          code: 'display-name-already-in-use',
          message: 'Ce pseudo est déjà utilisé.',
        );
      }
    } on AuthFailure {
      rethrow;
    } on Object catch (e) {
      developer.log('display name availability check skipped: $e', level: 800);
    }
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _requireAuth.resetPasswordForEmail(
        email,
        redirectTo: 'rihla://auth-callback',
      );
    } on AuthException catch (e) {
      throw _mapException(e);
    }
  }

  Future<void> resendSignupConfirmationEmail({required String email}) async {
    try {
      await _requireAuth.resend(type: OtpType.signup, email: email);
    } on AuthException catch (e) {
      throw _mapException(e);
    }
  }

  Future<void> updateDisplayName(String displayName) async {
    final auth = _requireAuth;
    final user = auth.currentUser;
    if (user == null) {
      throw const AuthFailure(
        code: 'no-current-user',
        message: 'Utilisateur introuvable.',
      );
    }
    try {
      await ensureDisplayNameAvailable(displayName, excludingUserId: user.id);
      await auth.updateUser(
        UserAttributes(data: {'display_name': displayName}),
      );
    } on AuthException catch (e) {
      throw _mapException(e);
    }
  }

  Future<void> reauthenticate(String currentPassword) async {
    final auth = _requireAuth;
    final email = auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      throw const AuthFailure(
        code: 'no-current-user',
        message: 'Utilisateur introuvable.',
      );
    }
    try {
      await auth.signInWithPassword(email: email, password: currentPassword);
    } on AuthException catch (e) {
      throw _mapException(e);
    }
  }

  Future<void> updatePassword(String newPassword) async {
    final auth = _requireAuth;
    if (auth.currentUser == null) {
      throw const AuthFailure(
        code: 'no-current-user',
        message: 'Utilisateur introuvable.',
      );
    }
    try {
      await auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      throw _mapException(e);
    }
  }

  Future<void> updateEmail(String newEmail) async {
    final auth = _requireAuth;
    if (auth.currentUser == null) {
      throw const AuthFailure(
        code: 'no-current-user',
        message: 'Utilisateur introuvable.',
      );
    }
    try {
      await auth.updateUser(UserAttributes(email: newEmail));
    } on AuthException catch (e) {
      throw _mapException(e);
    }
  }

  Future<void> deleteAccount() async {
    final auth = _requireAuth;
    final user = auth.currentUser;
    if (user == null) {
      throw const AuthFailure(
        code: 'no-current-user',
        message: 'Utilisateur introuvable.',
      );
    }
    try {
      await Supabase.instance.client.functions.invoke('delete_account');

      try {
        await auth.signOut();
      } on Object catch (e) {
        developer.log(
          'deleteAccount: signOut local échoué après suppression serveur '
          'réussie. La session sera nettoyée au prochain démarrage.',
          name: 'SupabaseAuthService',
          error: e,
          level: 900,
        );
      }
    } on FunctionException catch (e) {
      throw AuthFailure(
        code: 'delete-failed',
        message:
            e.details?.toString() ??
            'Suppression impossible. Réessaye plus tard.',
      );
    } on AuthException catch (e) {
      throw _mapException(e);
    }
  }

  Future<void> signOut() async {
    final auth = _authOrNull;
    if (auth == null) {
      return;
    }
    try {
      await auth.signOut();
    } on AuthException catch (e) {
      throw _mapException(e);
    }
  }

  AuthFailure _mapException(AuthException e) {
    final raw = e.message.toLowerCase();
    final String code;
    final String message;

    if (raw.contains('invalid login credentials') ||
        raw.contains('invalid email or password')) {
      code = 'invalid-credentials';
      message = 'Email ou mot de passe incorrect.';
    } else if (raw.contains('user already registered') ||
        raw.contains('already registered') ||
        raw.contains('already exists') ||
        raw.contains('email exists')) {
      code = 'email-already-in-use';
      message = 'Cet email est déjà utilisé.';
    } else if (raw.contains('duplicate key') && raw.contains('display_name')) {
      code = 'display-name-already-in-use';
      message = 'Ce pseudo est déjà utilisé.';
    } else if (raw.contains('email not confirmed')) {
      code = 'email-not-confirmed';
      message = 'Confirmez votre email avant de vous connecter.';
    } else if (raw.contains('password should be') ||
        raw.contains('weak password')) {
      code = 'weak-password';
      message = 'Mot de passe trop faible.';
    } else if (raw.contains('invalid email') ||
        raw.contains('email_address_invalid')) {
      code = 'invalid-email';
      message = 'Email invalide.';
    } else if (raw.contains('new password should be different')) {
      code = 'same-password';
      message = 'Le nouveau mot de passe doit être différent de l\'ancien.';
    } else if (raw.contains('network') || raw.contains('socket')) {
      code = 'network';
      message = 'Problème de connexion. Vérifiez votre réseau.';
    } else {
      code = 'unknown';
      message = 'Authentification impossible. Réessayez plus tard.';
    }
    return AuthFailure(code: code, message: message);
  }
}
