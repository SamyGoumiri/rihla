import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:rihla/core/services/auth_failure.dart';
import 'package:rihla/core/services/connectivity_service.dart';
import 'package:rihla/core/services/profile_photo_service.dart';
import 'package:rihla/core/services/profile_service.dart';
import 'package:rihla/core/services/supabase_auth_service.dart';
import 'package:rihla/core/theme/rihla_palette.dart';
import 'package:rihla/features/settings/presentation/account_edit_pages.dart';
import 'package:rihla/features/settings/presentation/settings_icon_box.dart';
import 'package:rihla/theme/spacing.dart';
import 'package:rihla/theme/typography.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({
    super.key,
    SupabaseAuthService? authService,
    ProfileService? profileService,
    ProfilePhotoService? profilePhotoService,
    ConnectivityService? connectivity,
  }) : _authService = authService,
       _profileService = profileService,
       _profilePhotoService = profilePhotoService,
       _connectivity = connectivity;

  final SupabaseAuthService? _authService;
  final ProfileService? _profileService;
  final ProfilePhotoService? _profilePhotoService;
  final ConnectivityService? _connectivity;

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  late final SupabaseAuthService _authService =
      widget._authService ?? SupabaseAuthService();
  late final ProfileService _profileService =
      widget._profileService ?? ProfileService();
  late final ProfilePhotoService _profilePhotoService =
      widget._profilePhotoService ?? ProfilePhotoService();
  late final ConnectivityService _connectivity =
      widget._connectivity ?? ConnectivityService();

  ProfileData? _profile;
  bool _isLoading = true;
  bool _isUpdatingPhoto = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await _profileWithAuthFallback();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _isLoading = false;
    });
  }

  Future<ProfileData> _profileWithAuthFallback() async {
    final profile = await _profileService.getProfile();
    if (profile.displayName.trim().isNotEmpty) return profile;

    final authName = _authService.currentDisplayName?.trim() ?? '';
    if (authName.isEmpty) return profile;

    final updated = profile.copyWith(displayName: authName);
    await _profileService.saveProfile(updated);
    return updated;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _ensureOnline(String message) async {
    bool online;
    try {
      online = await _connectivity.isOnlineNow().timeout(
        const Duration(seconds: 3),
      );
    } on Object {
      online = true;
    }
    if (!online && mounted) {
      _showSnack(message);
    }
    return online;
  }

  Future<void> _editDisplayName() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EditDisplayNamePage(
          initialDisplayName: _profile?.displayName ?? '',
          authService: _authService,
          onSaved: (String name) async {
            final current = await _profileService.getProfile();
            await _profileService.saveProfile(
              current.copyWith(displayName: name),
            );
          },
        ),
      ),
    );
    if (saved == true) {
      await _load();
      _showSnack('Pseudo mis à jour.');
    }
  }

  Future<void> _changePhoto() async {
    if (_isUpdatingPhoto) return;
    setState(() => _isUpdatingPhoto = true);

    try {
      final result = await _profilePhotoService.pickAndPersist(
        previousPhotoPath: _profile?.photoPath,
      );
      if (!mounted) return;
      if (result.error != null) {
        _showSnack(result.error!);
        return;
      }
      if (result.isCancelled || result.path == null) return;

      final current = await _profileService.getProfile();
      ProfileData updated = current.copyWith(photoPath: result.path);
      await _profileService.saveProfile(updated);

      bool uploaded = true;
      final uid = _authService.currentUid;
      if (uid != null && uid.isNotEmpty) {
        final url = await _profilePhotoService.uploadToCloud(
          uid: uid,
          localPath: result.path!,
        );
        if (!mounted) return;
        if (url != null && url.isNotEmpty) {
          updated = updated.copyWith(photoUrl: url);
          await _profileService.saveProfile(updated);
        } else {
          uploaded = false;
        }
      }

      await _load();
      _showSnack(
        uploaded
            ? 'Photo de profil mise à jour.'
            : 'Photo enregistrée localement. Reconnectez-vous puis '
                  'remplacez-la pour la synchroniser avec votre compte.',
      );
    } finally {
      if (mounted) setState(() => _isUpdatingPhoto = false);
    }
  }

  Future<void> _editPassword() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EditPasswordPage(authService: _authService),
      ),
    );
    if (saved == true) {
      _showSnack('Mot de passe mis à jour.');
    }
  }

  Future<void> _editEmail() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => EditEmailPage(
          initialEmail: _authService.currentEmail ?? '',
          authService: _authService,
        ),
      ),
    );
    if (saved == true) {
      _showSnack('Email de vérification envoyé.');
      setState(() {});
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final passwordController = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        final palette = RihlaPalette.of(sheetContext);
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            16 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: palette.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.delete_forever_outlined,
                    color: palette.dangerForeground,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Supprimer mon compte',
                    style: AppTypography.title3.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: palette.dangerForeground,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Cette action efface définitivement votre compte et les données associées (favoris, historique, avis). Aucune restauration n\'est possible.',
                style: AppTypography.body.copyWith(
                  fontSize: 13.6,
                  height: 1.4,
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Mot de passe',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                      ),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.dangerForeground,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(46),
                      ),
                      child: const Text('Supprimer'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;
    if (passwordController.text.isEmpty) {
      _showSnack('Mot de passe requis pour confirmer la suppression.');
      return;
    }
    if (!await _ensureOnline(
      'Vous êtes hors ligne. Reconnectez-vous pour supprimer votre compte.',
    )) {
      return;
    }

    try {
      await _authService.reauthenticate(passwordController.text);
      await _authService.deleteAccount();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthFailure catch (error) {
      _showSnack(error.message);
    } catch (_) {
      _showSnack('Suppression impossible.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final RihlaPalette palette = RihlaPalette.of(context);
    final email = _authService.currentEmail ?? '—';
    final localDisplayName = _profile?.displayName.trim() ?? '';
    final authDisplayName = _authService.currentDisplayName?.trim() ?? '';
    final displayName = localDisplayName.isNotEmpty
        ? localDisplayName
        : authDisplayName.isNotEmpty
        ? authDisplayName
        : 'Voyageur RIHLA';
    final avatarImage = _avatarImage(
      photoPath: _profile?.photoPath.trim() ?? '',
      photoUrl: _profile?.photoUrl.trim() ?? '',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Compte',
          style: AppTypography.title3.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              color: palette.cardSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.divider),
            ),
            child: Column(
              children: <Widget>[
                _AccountPhotoTile(
                  image: avatarImage,
                  isUpdating: _isUpdatingPhoto,
                  onTap: _changePhoto,
                ),
                Divider(height: 1, color: palette.divider),
                _AccountTile(
                  icon: Icons.person_outline_rounded,
                  title: 'Pseudo',
                  value: displayName,
                  onTap: _editDisplayName,
                ),
                Divider(height: 1, color: palette.divider),
                _AccountTile(
                  icon: Icons.alternate_email_rounded,
                  title: 'Email',
                  value: email,
                  onTap: _editEmail,
                ),
                Divider(height: 1, color: palette.divider),
                _AccountTile(
                  icon: Icons.lock_outline_rounded,
                  title: 'Mot de passe',
                  value: '••••••••',
                  onTap: _editPassword,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x4),
          Text(
            'Zone sensible',
            style: AppTypography.title3.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          Container(
            decoration: BoxDecoration(
              color: palette.cardSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.divider),
            ),
            child: ListTile(
              minLeadingWidth: 38,
              leading: SettingsIconBox(
                icon: Icons.delete_forever_outlined,
                color: palette.dangerForeground,
                backgroundColor: palette.dangerBackground,
              ),
              title: Text(
                'Supprimer mon compte',
                style: TextStyle(
                  color: palette.dangerForeground,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: const Text(
                'Action définitive : compte et données associées effacés.',
              ),
              onTap: _confirmDeleteAccount,
            ),
          ),
        ],
      ),
    );
  }

  ImageProvider<Object>? _avatarImage({
    required String photoPath,
    required String photoUrl,
  }) {
    if (photoPath.isNotEmpty && File(photoPath).existsSync()) {
      return FileImage(File(photoPath));
    }
    if (photoUrl.isNotEmpty) return CachedNetworkImageProvider(photoUrl);
    return null;
  }
}

class _AccountPhotoTile extends StatelessWidget {
  const _AccountPhotoTile({
    required this.image,
    required this.isUpdating,
    required this.onTap,
  });

  final ImageProvider<Object>? image;
  final bool isUpdating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final RihlaPalette palette = RihlaPalette.of(context);
    return ListTile(
      minLeadingWidth: 38,
      leading: SizedBox(
        width: 38,
        height: 38,
        child: CircleAvatar(
          backgroundColor: palette.brandPrimarySoft,
          foregroundImage: image,
          child: image == null
              ? Icon(
                  Icons.person_outline_rounded,
                  color: palette.brandPrimaryOnSoft,
                  size: 20,
                )
              : null,
        ),
      ),
      title: const Text('Photo de profil'),
      subtitle: Text(
        'Modifier l\'avatar public',
        style: TextStyle(color: palette.textSecondary),
      ),
      trailing: isUpdating
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.chevron_right_rounded, color: palette.textSecondary),
      onTap: isUpdating ? null : onTap,
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final RihlaPalette palette = RihlaPalette.of(context);
    return ListTile(
      minLeadingWidth: 38,
      leading: SettingsIconBox(icon: icon),
      title: Text(title),
      subtitle: Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: palette.textSecondary),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: palette.textSecondary),
      onTap: onTap,
    );
  }
}
