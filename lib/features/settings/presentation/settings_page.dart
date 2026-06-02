import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:rihla/core/services/favorites_service.dart';
import 'package:rihla/core/services/history_service.dart';
import 'package:rihla/core/services/profile_photo_service.dart';
import 'package:rihla/core/services/profile_service.dart';
import 'package:rihla/core/services/rating_service.dart';
import 'package:rihla/core/services/supabase_auth_service.dart';
import 'package:rihla/core/theme/rihla_palette.dart';
import 'package:rihla/features/favorites/presentation/favorites_page.dart';
import 'package:rihla/features/settings/presentation/app_settings_page.dart';
import 'package:rihla/features/settings/presentation/profile_history_page.dart';
import 'package:rihla/features/settings/presentation/profile_reviews_page.dart';
import 'package:rihla/features/settings/presentation/settings_icon_box.dart';
import 'package:rihla/theme/spacing.dart';
import 'package:rihla/theme/typography.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.isGuestMode,
    required this.onExitSession,
    ProfileService? profileService,
    FavoritesService? favoritesService,
    HistoryService? historyService,
    RatingService? ratingService,
    ProfilePhotoService? profilePhotoService,
    SupabaseAuthService? authService,
  }) : _profileService = profileService,
       _favoritesService = favoritesService,
       _historyService = historyService,
       _ratingService = ratingService,
       _profilePhotoService = profilePhotoService,
       _authService = authService;

  final bool isGuestMode;
  final VoidCallback onExitSession;
  final ProfileService? _profileService;
  final FavoritesService? _favoritesService;
  final HistoryService? _historyService;
  final RatingService? _ratingService;
  final ProfilePhotoService? _profilePhotoService;
  final SupabaseAuthService? _authService;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final ProfileService _profileService =
      widget._profileService ?? ProfileService();
  late final FavoritesService _favoritesService =
      widget._favoritesService ?? FavoritesService();
  late final HistoryService _historyService =
      widget._historyService ?? HistoryService();
  late final RatingService _ratingService =
      widget._ratingService ?? RatingService();
  late final ProfilePhotoService _profilePhotoService =
      widget._profilePhotoService ?? ProfilePhotoService();
  late final SupabaseAuthService _authService =
      widget._authService ?? SupabaseAuthService();

  StreamSubscription<void>? _favoritesSubscription;
  StreamSubscription<void>? _historySubscription;
  StreamSubscription<void>? _ratingSubscription;
  StreamSubscription<void>? _profileSubscription;

  ProfileData? _profile;
  int _favoritesCount = 0;
  int _historyCount = 0;
  int _reviewsCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _favoritesSubscription = FavoritesService.changes.listen((_) {
      _loadCounts();
    });
    _historySubscription = HistoryService.changes.listen((_) {
      _loadCounts();
    });
    _ratingSubscription = RatingService.changes.listen((_) {
      _loadCounts();
    });
    _profileSubscription = ProfileService.changes.listen((_) {
      _refreshProfile();
    });
    _loadData();
  }

  @override
  void dispose() {
    _favoritesSubscription?.cancel();
    _historySubscription?.cancel();
    _ratingSubscription?.cancel();
    _profileSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final ProfileData profile = await _profileWithAuthFallback();
    if (!mounted) return;
    setState(() => _profile = profile);
    await _loadCounts();
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _refreshProfile() async {
    final ProfileData profile = await _profileWithAuthFallback();
    if (!mounted) return;
    setState(() => _profile = profile);
  }

  Future<ProfileData> _profileWithAuthFallback() async {
    final ProfileData profile = await _profileService.getProfile();
    if (widget.isGuestMode || profile.displayName.trim().isNotEmpty) {
      return profile;
    }

    final String authName = _authService.currentDisplayName?.trim() ?? '';
    if (authName.isEmpty) return profile;

    final updated = profile.copyWith(displayName: authName);
    await _profileService.saveProfile(updated);
    return updated;
  }

  Future<void> _loadCounts() async {
    final List<String> favorites = await _favoritesService.getFavorites();
    final int historyCount = await _historyService.getHistoryCount();
    final reviews = await _ratingService.getReviews();

    if (!mounted) return;
    setState(() {
      _favoritesCount = favorites.length;
      _historyCount = historyCount;
      _reviewsCount = reviews.length;
    });
  }

  Future<void> _openFavorites() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const FavoritesPage()));
    if (mounted) await _loadCounts();
  }

  Future<void> _openHistory() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ProfileHistoryPage()));
    if (mounted) await _loadCounts();
  }

  Future<void> _openReviews() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileReviewsPage(ratingService: _ratingService),
      ),
    );
    if (mounted) await _loadCounts();
  }

  Future<void> _openAppSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AppSettingsPage(
          isGuestMode: widget.isGuestMode,
          profileService: _profileService,
          profilePhotoService: _profilePhotoService,
          authService: _authService,
        ),
      ),
    );
    if (mounted) await _loadData();
  }

  String _userName() {
    if (widget.isGuestMode) return 'Invité';

    final String profileName = _profile?.displayName.trim() ?? '';
    if (profileName.isNotEmpty) return profileName;

    final String authName = _authService.currentDisplayName?.trim() ?? '';
    if (authName.isNotEmpty) return authName;

    return 'Voyageur RIHLA';
  }

  String _userSubtitle() {
    if (widget.isGuestMode) return '';
    final String email = _authService.currentEmail?.trim() ?? '';
    return email.isNotEmpty ? email : 'Compte voyageur';
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

  Widget _buildHeader(RihlaPalette palette) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            'Profil',
            style: AppTypography.title3.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: palette.textPrimary,
            ),
          ),
        ),
        IconButton.filledTonal(
          onPressed: _openAppSettings,
          tooltip: 'Ouvrir les paramètres',
          style: IconButton.styleFrom(
            backgroundColor: palette.cardSurface,
            foregroundColor: palette.brandPrimary,
          ),
          icon: const Icon(Icons.settings_rounded),
        ),
      ],
    );
  }

  Widget _buildProfileCard({
    required RihlaPalette palette,
    required String userName,
    required String subtitle,
    required ImageProvider<Object>? avatarImage,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              _ProfileAvatar(avatarImage: avatarImage),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      userName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.title3.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          fontSize: 13,
                          color: palette.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.onExitSession,
              icon: Icon(
                widget.isGuestMode ? Icons.login_rounded : Icons.logout_rounded,
              ),
              label: Text(
                widget.isGuestMode ? 'Se connecter' : 'Se déconnecter',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                backgroundColor: widget.isGuestMode
                    ? palette.brandPrimary
                    : palette.dangerForeground,
                foregroundColor: Colors.white,
                textStyle: AppTypography.button.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestBanner(RihlaPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: palette.brandPrimarySoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        'Connectez-vous pour sauvegarder vos favoris et synchroniser votre profil.',
        style: AppTypography.body.copyWith(
          fontSize: 14,
          height: 1.35,
          color: palette.brandPrimaryOnSoft,
        ),
      ),
    );
  }

  Widget _buildActivitySection(RihlaPalette palette) {
    return _Section(
      title: 'Activité',
      children: <Widget>[
        _ActionTile(
          icon: Icons.favorite_border_rounded,
          title: 'Mes favoris',
          subtitle:
              '$_favoritesCount site${_favoritesCount > 1 ? 's' : ''} enregistré${_favoritesCount > 1 ? 's' : ''}',
          onTap: _openFavorites,
        ),
        _ActionTile(
          icon: Icons.history_rounded,
          title: 'Historique des consultations',
          subtitle:
              '$_historyCount site${_historyCount > 1 ? 's' : ''} consulté${_historyCount > 1 ? 's' : ''}',
          onTap: _openHistory,
          hasDivider: true,
        ),
        _ActionTile(
          icon: Icons.rate_review_outlined,
          title: 'Mes avis',
          subtitle: '$_reviewsCount avis publié${_reviewsCount > 1 ? 's' : ''}',
          onTap: _openReviews,
          hasDivider: true,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final RihlaPalette palette = RihlaPalette.of(context);
    final String photoPath = _profile?.photoPath.trim() ?? '';
    final String photoUrl = _profile?.photoUrl.trim() ?? '';

    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: palette.brandPrimary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
            children: <Widget>[
              _buildHeader(palette),
              const SizedBox(height: AppSpacing.x3),
              _buildProfileCard(
                palette: palette,
                userName: _userName(),
                subtitle: _userSubtitle(),
                avatarImage: _avatarImage(
                  photoPath: photoPath,
                  photoUrl: photoUrl,
                ),
              ),
              const SizedBox(height: AppSpacing.x3),
              if (widget.isGuestMode) _buildGuestBanner(palette),
              if (!widget.isGuestMode) _buildActivitySection(palette),
              const SizedBox(height: AppSpacing.x8),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final RihlaPalette palette = RihlaPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: AppTypography.title3.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: palette.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.x2),
        Container(
          decoration: BoxDecoration(
            color: palette.cardSurface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.hasDivider = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool hasDivider;

  @override
  Widget build(BuildContext context) {
    final RihlaPalette palette = RihlaPalette.of(context);
    final String semanticsLabel = subtitle == null
        ? title
        : '$title. $subtitle';

    return Column(
      children: <Widget>[
        Semantics(
          button: true,
          label: semanticsLabel,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
            minLeadingWidth: 38,
            leading: SettingsIconBox(icon: icon),
            title: Text(
              title,
              style: AppTypography.bodyStrong.copyWith(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            subtitle: subtitle == null
                ? null
                : Text(
                    subtitle!,
                    style: AppTypography.caption.copyWith(
                      fontSize: 12,
                      color: palette.textSecondary,
                    ),
                  ),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: palette.textSecondary,
            ),
            onTap: onTap,
          ),
        ),
        if (hasDivider)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
            child: Divider(height: 1, color: palette.divider),
          ),
      ],
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.avatarImage});

  final ImageProvider<Object>? avatarImage;

  @override
  Widget build(BuildContext context) {
    final RihlaPalette palette = RihlaPalette.of(context);
    return Semantics(
      label: 'Photo de profil',
      child: CircleAvatar(
        radius: 30,
        backgroundColor: palette.brandPrimarySoft,
        foregroundImage: avatarImage,
        child: avatarImage == null
            ? Icon(
                Icons.explore_outlined,
                color: palette.brandPrimaryOnSoft,
                size: 28,
              )
            : null,
      ),
    );
  }
}
