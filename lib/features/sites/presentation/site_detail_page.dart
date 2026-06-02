import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:rihla/core/constants/categories.dart';
import 'package:rihla/core/services/auth_uid_resolver.dart';
import 'package:rihla/core/services/connectivity_service.dart';
import 'package:rihla/core/services/favorites_service.dart';
import 'package:rihla/core/services/history_service.dart';
import 'package:rihla/core/services/rating_service.dart';
import 'package:rihla/core/services/user_data_sync_service.dart';
import 'package:rihla/core/state/session_mode.dart';
import 'package:rihla/core/theme/rihla_palette.dart';
import 'package:rihla/core/widgets/site_rating_label.dart';
import 'package:rihla/data/models/site_review.dart';
import 'package:rihla/data/models/tourist_site.dart';
import 'package:rihla/features/navigation/presentation/navigation_page.dart';
import 'package:rihla/features/sites/presentation/site_image_carousel.dart';
import 'package:rihla/theme/spacing.dart';
import 'package:rihla/theme/typography.dart';

class SiteDetailPage extends StatefulWidget {
  const SiteDetailPage({
    super.key,
    required this.site,
    RatingService? ratingService,
    FavoritesService? favoritesService,
    HistoryService? historyService,
    UserDataSyncService? syncService,
    ConnectivityService? connectivityService,
  }) : _ratingService = ratingService,
       _favoritesService = favoritesService,
       _historyService = historyService,
       _syncService = syncService,
       _connectivityService = connectivityService;

  final TouristSite site;
  final RatingService? _ratingService;
  final FavoritesService? _favoritesService;
  final HistoryService? _historyService;
  final UserDataSyncService? _syncService;
  final ConnectivityService? _connectivityService;

  @override
  State<SiteDetailPage> createState() => _SiteDetailPageState();
}

class _SiteDetailPageState extends State<SiteDetailPage> {
  late final RatingService _ratingService =
      widget._ratingService ?? RatingService();
  late final FavoritesService _favoritesService =
      widget._favoritesService ?? FavoritesService();
  late final HistoryService _historyService =
      widget._historyService ?? HistoryService();
  late final UserDataSyncService _syncService =
      widget._syncService ?? UserDataSyncService();
  late final ConnectivityService _connectivity =
      widget._connectivityService ?? ConnectivityService();

  final TextEditingController _commentController = TextEditingController();
  double? _userRating;
  bool _isFavorite = false;
  SiteReview? _existingReview;
  bool _isSavingReview = false;
  bool _isEditingReview = false;
  List<PublicReview> _publicReviews = const <PublicReview>[];
  bool _isLoadingPublicReviews = true;

  bool _reviewsOffline = false;

  @override
  void initState() {
    super.initState();
    _loadReview();
    _loadFavoriteState();
    _loadPublicReviews();
    _recordVisit();
  }

  Future<void> _loadPublicReviews() async {
    final online = await _isOnline();
    if (!online) {
      if (!mounted) return;
      setState(() {
        _publicReviews = const <PublicReview>[];
        _isLoadingPublicReviews = false;
        _reviewsOffline = true;
      });
      return;
    }
    final reviews = await _ratingService.fetchPublicReviewsForSite(
      widget.site.id,
    );
    if (!mounted) return;
    setState(() {
      _publicReviews = reviews;
      _isLoadingPublicReviews = false;
      _reviewsOffline = false;
    });
  }

  Future<bool> _isOnline() async {
    try {
      return await _connectivity.isOnlineNow().timeout(
        const Duration(seconds: 3),
      );
    } on Object {
      return true;
    }
  }

  Future<bool> _ensureOnline(String message) async {
    final online = await _isOnline();
    if (!online && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
    return online;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadFavoriteState() async {
    final isFavorite = await _favoritesService.isFavorite(widget.site.id);
    if (!mounted) return;
    setState(() {
      _isFavorite = isFavorite;
    });
  }

  Future<void> _recordVisit() async {
    if (SessionModeNotifier.isGuest) return;
    await _historyService.recordVisit(widget.site.id);
  }

  Future<void> _loadReview() async {
    final review = await _ratingService.getReview(widget.site.id);
    if (!mounted) return;
    setState(() {
      _existingReview = review;
      _userRating = review?.rating;
      _commentController.text = '';
      _isEditingReview = false;
    });
  }

  void _rateSite(double rating) {
    setState(() {
      _userRating = rating;
    });
  }

  void _startEditingReview() {
    _openReviewEditor(existingReview: _existingReview);
  }

  void _cancelEditingReview() {
    setState(() {
      _isEditingReview = _existingReview == null;
      _userRating = _existingReview?.rating;
      _commentController.text = '';
    });
  }

  Future<void> _saveReview() async {
    final rating = _userRating ?? 0;
    if (rating <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choisissez une note avant d\'enregistrer.'),
        ),
      );
      return;
    }

    if (!await _ensureOnline(
      'Vous êtes hors ligne. Reconnectez-vous pour publier votre avis.',
    )) {
      return;
    }
    if (!mounted) return;

    final wasEditing = _existingReview != null;

    setState(() {
      _isSavingReview = true;
    });

    try {
      final review = SiteReview(
        siteId: widget.site.id,
        rating: rating,
        comment: _commentController.text.trim(),
        updatedAt: DateTime.now(),
      );
      await _ratingService.setReview(review);
      if (!mounted) return;
      setState(() {
        _existingReview = review;
        _isEditingReview = false;
        _commentController.text = '';
      });

      final pushed = await _syncService.pushPending(resolveCurrentUid());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            pushed
                ? (wasEditing
                      ? 'Votre avis a été mis à jour.'
                      : 'Votre avis a été publié.')
                : 'Avis enregistré. Il sera publié dès le retour de la connexion.',
          ),
        ),
      );
      await _loadPublicReviews();
    } finally {
      if (mounted) {
        setState(() {
          _isSavingReview = false;
        });
      }
    }
  }

  Future<void> _openReviewEditor({SiteReview? existingReview}) async {
    if (!await _ensureOnline(
      'Vous êtes hors ligne. Reconnectez-vous pour publier ou modifier un avis.',
    )) {
      return;
    }
    if (!mounted) return;

    double? sheetRating = existingReview?.rating ?? _userRating;
    final controller = TextEditingController(
      text: existingReview?.comment ?? '',
    );
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        showDragHandle: true,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
                  ),
                  child: _ReviewEditor(
                    site: widget.site,
                    existingReview: existingReview,
                    isSaving: _isSavingReview,
                    userRating: sheetRating,
                    commentController: controller,
                    onRate: (rating) {
                      setSheetState(() {
                        sheetRating = rating;
                      });
                    },
                    onSave: () async {
                      if (sheetRating == null || sheetRating! <= 0) {
                        await showDialog<void>(
                          context: sheetContext,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Note manquante'),
                            content: const Text(
                              'Choisissez une note (1 à 5 étoiles) avant d\'enregistrer votre avis.',
                            ),
                            actions: <Widget>[
                              FilledButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
                                child: const Text('Compris'),
                              ),
                            ],
                          ),
                        );
                        return;
                      }
                      setState(() {
                        _userRating = sheetRating;
                        _commentController.text = controller.text;
                      });
                      await _saveReview();
                      if (sheetContext.mounted) {
                        Navigator.of(sheetContext).pop();
                      }
                    },
                    onCancel: () => Navigator.of(sheetContext).pop(),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _deleteReview() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer votre avis ?'),
        content: const Text(
          'Votre note et votre commentaire seront définitivement '
          'supprimés. Vous pourrez en publier un nouveau plus tard.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    if (!await _ensureOnline(
      'Vous êtes hors ligne. Reconnectez-vous pour supprimer votre avis.',
    )) {
      return;
    }
    if (!mounted) return;

    await _ratingService.removeReview(widget.site.id);
    if (!mounted) return;
    setState(() {
      _existingReview = null;
      _userRating = null;
      _commentController.clear();
      _isEditingReview = true;
    });

    final pushed = await _syncService.pushPending(resolveCurrentUid());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          pushed
              ? 'Votre avis a été supprimé.'
              : 'Suppression enregistrée. Elle sera appliquée dès le retour de la connexion.',
        ),
      ),
    );
    await _loadPublicReviews();
  }

  Future<void> _setPublicReviewReaction(
    PublicReview review,
    String reaction,
  ) async {
    if (SessionModeNotifier.isGuest) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connectez-vous pour réagir aux avis.')),
      );
      return;
    }
    if (!await _ensureOnline(
      'Vous êtes hors ligne. Reconnectez-vous pour réagir aux avis.',
    )) {
      return;
    }
    if (!mounted) return;
    if (review.userReaction == reaction) {
      await _ratingService.removeReviewReaction(review);
    } else {
      await _ratingService.setReviewReaction(
        review: review,
        reaction: reaction,
      );
    }
    if (!mounted) return;
    await _loadPublicReviews();
  }

  PublicReview? get _myPublicReview {
    final uid = resolveCurrentUid();
    if (uid == null) return null;
    for (final review in _publicReviews) {
      if (review.authorUserId == uid) return review;
    }
    return null;
  }

  Future<void> _openReplies(
    PublicReview review, {
    bool focusInput = false,
  }) async {
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => _ReviewRepliesSheet(
          review: review,
          ratingService: _ratingService,
          connectivity: _connectivity,
          formatDate: _formatUpdatedAt,
          autofocusInput: focusInput,
        ),
      ),
    );
    if (!mounted) return;

    await _loadPublicReviews();
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  String _formatUpdatedAt(DateTime date) {
    return '${_twoDigits(date.day)}/${_twoDigits(date.month)}/${date.year} à '
        '${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';
  }

  Future<void> _toggleFavorite() async {
    await _favoritesService.toggleFavorite(widget.site.id);
    if (!mounted) return;
    setState(() {
      _isFavorite = !_isFavorite;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isFavorite ? 'Ajouté aux favoris.' : 'Retiré des favoris.',
        ),
      ),
    );
  }

  void _openRoute() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NavigationPage(destination: widget.site),
      ),
    );
  }

  void _openFullDescription() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return _SiteAboutSheet(site: widget.site);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final RihlaPalette palette = RihlaPalette.of(context);
    final bool isGuest = SessionModeNotifier.isGuest;

    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: palette.scaffoldBackground,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Retour',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: <Widget>[
          if (!isGuest)
            IconButton(
              icon: Icon(
                _isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
              ),
              tooltip: _isFavorite
                  ? 'Retirer des favoris'
                  : 'Ajouter aux favoris',
              color: _isFavorite ? palette.brandPrimary : palette.textPrimary,
              onPressed: _toggleFavorite,
            ),
        ],
      ),
      body: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: SiteImageCarousel(
                imageUrls: widget.site.allImageUrls,
                fallback: Container(
                  color: palette.softSurface,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    size: 56,
                    color: palette.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            sliver: SliverList(
              delegate: SliverChildListDelegate(<Widget>[
                _SiteHeaderCard(site: widget.site),
                const SizedBox(height: 16),
                _AboutCard(
                  site: widget.site,
                  userRating: _existingReview?.rating,
                  onReadMore: _openFullDescription,
                ),
                const SizedBox(height: AppSpacing.x3),
                _RouteCard(site: widget.site, onOpenRoute: _openRoute),
                const SizedBox(height: AppSpacing.x3),
                if (SessionModeNotifier.isGuest)
                  _GuestReviewCta(palette: palette)
                else
                  _ReviewSection(
                    site: widget.site,
                    existingReview: _existingReview,
                    isEditing: _isEditingReview,
                    isSaving: _isSavingReview,
                    userRating: _userRating,
                    commentController: _commentController,
                    onRate: _rateSite,
                    onStartEditing: _startEditingReview,
                    onCancelEditing: _cancelEditingReview,
                    onSave: _saveReview,
                    onDelete: _deleteReview,
                    formatDate: _formatUpdatedAt,
                    onAddReview: () => _openReviewEditor(),
                    likesCount: _myPublicReview?.likesCount ?? 0,
                    dislikesCount: _myPublicReview?.dislikesCount ?? 0,
                    repliesCount: _myPublicReview?.repliesCount ?? 0,
                    onOpenReplies: _myPublicReview == null
                        ? null
                        : () => _openReplies(_myPublicReview!),
                  ),
                const SizedBox(height: AppSpacing.x3),
                _PublicReviewsSection(
                  reviews: _publicReviews,
                  isLoading: _isLoadingPublicReviews,
                  isOffline: _reviewsOffline,
                  formatDate: _formatUpdatedAt,
                  onReaction: _setPublicReviewReaction,
                  onOpenReplies: _openReplies,
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicReviewsSection extends StatelessWidget {
  const _PublicReviewsSection({
    required this.reviews,
    required this.isLoading,
    required this.isOffline,
    required this.formatDate,
    required this.onReaction,
    required this.onOpenReplies,
  });

  final List<PublicReview> reviews;
  final bool isLoading;
  final bool isOffline;
  final String Function(DateTime) formatDate;
  final Future<void> Function(PublicReview review, String reaction) onReaction;
  final void Function(PublicReview review, {bool focusInput}) onOpenReplies;

  @override
  Widget build(BuildContext context) {
    final palette = RihlaPalette.of(context);

    final String? currentUid = resolveCurrentUid();
    final List<PublicReview> visibleReviews = currentUid == null
        ? reviews
        : reviews
              .where((PublicReview r) => r.authorUserId != currentUid)
              .toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.forum_outlined, size: 20, color: palette.brandPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Avis des voyageurs',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.title3.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!isLoading && !isOffline && reviews.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: palette.brandPrimarySoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: palette.starColor,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${(reviews.fold<double>(0, (s, r) => s + r.rating) / reviews.length).toStringAsFixed(1)} · ${reviews.length}',
                        style: AppTypography.caption.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: palette.brandPrimaryOnSoft,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (isOffline)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.wifi_off_rounded,
                    size: 18,
                    color: palette.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Les avis des voyageurs ne sont pas disponibles hors '
                      'ligne. Reconnectez-vous pour les consulter.',
                      style: AppTypography.body.copyWith(
                        fontSize: 13.6,
                        color: palette.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (visibleReviews.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                'Aucun autre avis pour le moment. Partagez votre expérience '
                'pour aider les voyageurs !',
                style: AppTypography.body.copyWith(
                  fontSize: 13.6,
                  color: palette.textSecondary,
                  height: 1.4,
                ),
              ),
            )
          else
            for (int i = 0; i < visibleReviews.take(3).length; i++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: i == visibleReviews.take(3).length - 1 ? 0 : 12,
                ),
                child: _PublicReviewTile(
                  review: visibleReviews[i],
                  formatDate: formatDate,
                  onReaction: onReaction,
                  onOpenReplies: onOpenReplies,
                ),
              ),
          if (!isLoading && visibleReviews.length > 3) ...<Widget>[
            const SizedBox(height: AppSpacing.x2),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => SafeArea(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                        shrinkWrap: true,
                        itemCount: visibleReviews.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: AppSpacing.x2),
                        itemBuilder: (_, index) => _PublicReviewTile(
                          review: visibleReviews[index],
                          formatDate: formatDate,
                          onReaction: onReaction,
                          onOpenReplies: onOpenReplies,
                        ),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.expand_more_rounded),
                label: const Text('Voir plus d\'avis'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PublicReviewTile extends StatelessWidget {
  const _PublicReviewTile({
    required this.review,
    required this.formatDate,
    required this.onReaction,
    required this.onOpenReplies,
  });

  final PublicReview review;
  final String Function(DateTime) formatDate;
  final Future<void> Function(PublicReview review, String reaction) onReaction;
  final void Function(PublicReview review, {bool focusInput}) onOpenReplies;

  @override
  Widget build(BuildContext context) {
    final palette = RihlaPalette.of(context);
    final author = review.authorName.isEmpty
        ? 'Voyageur RIHLA'
        : review.authorName;
    final currentUid = resolveCurrentUid();
    final bool isMine =
        !SessionModeNotifier.isGuest &&
        review.authorUserId.isNotEmpty &&
        review.authorUserId == currentUid;
    final canReact =
        !SessionModeNotifier.isGuest &&
        review.authorUserId.isNotEmpty &&
        !isMine;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: isMine
            ? palette.brandPrimary.withValues(alpha: 0.08)
            : palette.softSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMine ? palette.brandPrimary : palette.divider,
          width: isMine ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 15,
                backgroundColor: palette.brandPrimarySoft,
                foregroundImage: review.authorPhotoUrl.isEmpty
                    ? null
                    : CachedNetworkImageProvider(review.authorPhotoUrl),
                child: review.authorPhotoUrl.isEmpty
                    ? Text(
                        author.characters.first.toUpperCase(),
                        style: AppTypography.bodyStrong.copyWith(
                          fontSize: 13,
                          color: palette.brandPrimaryOnSoft,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyStrong.copyWith(
                              fontSize: 13.6,
                              color: palette.textPrimary,
                            ),
                          ),
                        ),
                        if (isMine) ...<Widget>[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: palette.brandPrimary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Vous',
                              style: AppTypography.caption.copyWith(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 1),
                    Text(
                      formatDate(review.updatedAt),
                      style: AppTypography.caption.copyWith(
                        fontSize: 11.6,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.star_rounded, size: 16, color: palette.starColor),
                  const SizedBox(width: 2),
                  Text(
                    review.rating.toStringAsFixed(1),
                    style: AppTypography.bodyStrong.copyWith(
                      fontSize: 13,
                      color: palette.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (review.comment.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              review.comment,
              style: AppTypography.body.copyWith(
                fontSize: 13.6,
                height: 1.4,
                color: palette.textPrimary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _ReactionButton(
                icon: Icons.thumb_up_alt_outlined,
                selectedIcon: Icons.thumb_up_alt_rounded,
                selected: review.userReaction == 'like',
                label: '${review.likesCount}',
                onPressed: canReact ? () => onReaction(review, 'like') : null,
              ),
              _ReactionButton(
                icon: Icons.thumb_down_alt_outlined,
                selectedIcon: Icons.thumb_down_alt_rounded,
                selected: review.userReaction == 'dislike',
                label: '${review.dislikesCount}',
                onPressed: canReact
                    ? () => onReaction(review, 'dislike')
                    : null,
              ),
              TextButton.icon(
                onPressed: () => onOpenReplies(review),
                icon: const Icon(Icons.forum_outlined, size: 16),
                label: Text(
                  review.repliesCount > 0
                      ? '${review.repliesCount} '
                            'réponse${review.repliesCount > 1 ? 's' : ''}'
                      : 'Voir les réponses',
                ),
                style: TextButton.styleFrom(
                  foregroundColor: palette.textSecondary,
                  minimumSize: const Size(36, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: AppTypography.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!SessionModeNotifier.isGuest)
                TextButton.icon(
                  onPressed: () => onOpenReplies(review, focusInput: true),
                  icon: const Icon(Icons.reply_rounded, size: 16),
                  label: const Text('Répondre'),
                  style: TextButton.styleFrom(
                    foregroundColor: palette.brandPrimary,
                    minimumSize: const Size(36, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: AppTypography.caption.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = RihlaPalette.of(context);
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(selected ? selectedIcon : icon, size: 16),
      label: Text(label.isEmpty ? ' ' : label),
      style: TextButton.styleFrom(
        foregroundColor: selected
            ? palette.brandPrimary
            : palette.textSecondary,
        minimumSize: const Size(36, 32),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _SiteHeaderCard extends StatelessWidget {
  const _SiteHeaderCard({required this.site});

  final TouristSite site;

  String _locationLabel() {
    final address = site.address.trim();
    final city = site.city.trim();
    if (address.isEmpty) return city;
    if (city.isEmpty) return address;
    if (address.toLowerCase().contains(city.toLowerCase())) {
      return address;
    }
    return '$address · $city';
  }

  List<SiteCategory> _orderedCategories() {
    final List<SiteCategory> result = <SiteCategory>[site.category];
    for (final String slug in site.categorySlugs) {
      if (slug == site.category.name) continue;
      for (final SiteCategory c in SiteCategory.values) {
        if (c.name == slug && !result.contains(c)) {
          result.add(c);
        }
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final RihlaPalette palette = RihlaPalette.of(context);
    final List<SiteCategory> categories = _orderedCategories();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: <Widget>[
                    for (final SiteCategory c in categories)
                      _CategoryBadge(category: c),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SiteRatingLabel(rating: site.averageRating, fontSize: 13.5),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            site.name,
            style: AppTypography.title1.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: palette.textPrimary,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.location_on_outlined,
                size: 16,
                color: palette.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _locationLabel(),
                  style: AppTypography.body.copyWith(
                    fontSize: 14,
                    color: palette.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});

  final SiteCategory category;

  @override
  Widget build(BuildContext context) {
    final RihlaPalette palette = RihlaPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: palette.brandPrimary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(category.icon, size: 13, color: palette.brandPrimary),
          const SizedBox(width: 6),
          Text(
            category.label,
            style: AppTypography.caption.copyWith(
              color: palette.brandPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({
    required this.site,
    required this.userRating,
    required this.onReadMore,
  });

  final TouristSite site;
  final double? userRating;
  final VoidCallback onReadMore;

  @override
  Widget build(BuildContext context) {
    final RihlaPalette palette = RihlaPalette.of(context);
    final intro = site.shortIntro();
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'À propos',
                  style: AppTypography.title3.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              if (userRating != null) ...<Widget>[
                Icon(Icons.star_rounded, color: palette.starColor, size: 18),
                const SizedBox(width: 4),
                Text(
                  userRating!.toStringAsFixed(1),
                  style: AppTypography.bodyStrong.copyWith(
                    fontSize: 13.6,
                    color: palette.textPrimary,
                  ),
                ),
              ] else
                Text(
                  'Pas encore noté',
                  style: AppTypography.caption.copyWith(
                    fontSize: 12,
                    color: palette.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            intro.isEmpty ? 'Description bientôt disponible.' : intro,
            style: AppTypography.body.copyWith(
              fontSize: 14.6,
              height: 1.5,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onReadMore,
              icon: const Icon(Icons.open_in_full_rounded, size: 16),
              label: const Text('Lire la suite'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.site, required this.onOpenRoute});

  final TouristSite site;
  final VoidCallback onOpenRoute;

  @override
  Widget build(BuildContext context) {
    final RihlaPalette palette = RihlaPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.divider),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: palette.brandPrimarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.route_rounded,
              color: palette.brandPrimaryOnSoft,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Itinéraire',
                  style: AppTypography.bodyStrong.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Lancer la navigation vers ${site.city}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    fontSize: 12.6,
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: onOpenRoute,
            style: FilledButton.styleFrom(
              backgroundColor: palette.brandPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              minimumSize: Size.zero,
            ),
            child: const Text('Y aller'),
          ),
        ],
      ),
    );
  }
}

class _SiteAboutSheet extends StatelessWidget {
  const _SiteAboutSheet({required this.site});

  final TouristSite site;

  @override
  Widget build(BuildContext context) {
    final RihlaPalette palette = RihlaPalette.of(context);
    final mediaQuery = MediaQuery.of(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: palette.cardSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
              22,
              4,
              22,
              22 + mediaQuery.viewInsets.bottom,
            ),
            children: <Widget>[
              Text(
                site.name,
                style: AppTypography.title2.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${site.category.label} · ${site.city}',
                style: AppTypography.caption.copyWith(
                  fontSize: 13,
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.x4),
              if (site.description.isNotEmpty) ...<Widget>[
                _SheetSectionTitle(label: 'Description', palette: palette),
                const SizedBox(height: 8),
                Text(
                  site.description,
                  style: AppTypography.body.copyWith(
                    fontSize: 14.6,
                    height: 1.5,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.x4),
              ],
              if (site.historicalInfo.isNotEmpty) ...<Widget>[
                _SheetSectionTitle(label: 'Histoire', palette: palette),
                const SizedBox(height: 8),
                Text(
                  site.historicalInfo,
                  style: AppTypography.body.copyWith(
                    fontSize: 14.6,
                    height: 1.5,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.x4),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SheetSectionTitle extends StatelessWidget {
  const _SheetSectionTitle({required this.label, required this.palette});

  final String label;
  final RihlaPalette palette;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: AppTypography.caption.copyWith(
        fontSize: 11.5,
        letterSpacing: 1,
        fontWeight: FontWeight.w800,
        color: palette.brandPrimary,
      ),
    );
  }
}

class _GuestReviewCta extends StatelessWidget {
  const _GuestReviewCta({required this.palette});

  final RihlaPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.brandPrimarySoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.brandPrimary.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.lock_outline_rounded,
            color: palette.brandPrimaryOnSoft,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Réservé aux comptes voyageurs',
                  style: AppTypography.bodyStrong.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: palette.brandPrimaryOnSoft,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Connectez-vous pour noter ce site, le mettre en favori et garder votre historique.',
                  style: AppTypography.caption.copyWith(
                    fontSize: 13,
                    color: palette.brandPrimaryOnSoft.withValues(alpha: 0.85),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({
    required this.site,
    required this.existingReview,
    required this.isEditing,
    required this.isSaving,
    required this.userRating,
    required this.commentController,
    required this.onRate,
    required this.onStartEditing,
    required this.onCancelEditing,
    required this.onSave,
    required this.onDelete,
    required this.formatDate,
    required this.onAddReview,
    required this.likesCount,
    required this.dislikesCount,
    required this.repliesCount,
    required this.onOpenReplies,
  });

  final TouristSite site;
  final SiteReview? existingReview;
  final bool isEditing;
  final bool isSaving;
  final double? userRating;
  final TextEditingController commentController;
  final ValueChanged<double> onRate;
  final VoidCallback onStartEditing;
  final VoidCallback onCancelEditing;
  final VoidCallback onSave;
  final VoidCallback onDelete;
  final String Function(DateTime) formatDate;
  final VoidCallback onAddReview;

  final int likesCount;
  final int dislikesCount;

  final int repliesCount;
  final VoidCallback? onOpenReplies;

  @override
  Widget build(BuildContext context) {
    final review = existingReview;
    if (review != null && !isEditing) {
      return _PublishedReviewCard(
        review: review,
        formatDate: formatDate,
        onEdit: onStartEditing,
        onDelete: isSaving ? null : onDelete,
        likesCount: likesCount,
        dislikesCount: dislikesCount,
        repliesCount: repliesCount,
        onOpenReplies: onOpenReplies,
      );
    }
    return _AddReviewCard(onAddReview: onAddReview);
  }
}

class _AddReviewCard extends StatelessWidget {
  const _AddReviewCard({required this.onAddReview});

  final VoidCallback onAddReview;

  @override
  Widget build(BuildContext context) {
    final palette = RihlaPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.rate_review_outlined, color: palette.brandPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Votre avis',
                  style: AppTypography.title3.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ajoutez une note obligatoire et un commentaire optionnel.',
                  style: AppTypography.caption.copyWith(
                    fontSize: 12.8,
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.x2),
                FilledButton.icon(
                  onPressed: onAddReview,
                  icon: const Icon(Icons.add_comment_outlined),
                  label: const Text('Ajouter un avis'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PublishedReviewCard extends StatelessWidget {
  const _PublishedReviewCard({
    required this.review,
    required this.formatDate,
    required this.onEdit,
    required this.onDelete,
    required this.likesCount,
    required this.dislikesCount,
    required this.repliesCount,
    required this.onOpenReplies,
  });

  final SiteReview review;
  final String Function(DateTime) formatDate;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;
  final int likesCount;
  final int dislikesCount;
  final int repliesCount;
  final VoidCallback? onOpenReplies;

  @override
  Widget build(BuildContext context) {
    final RihlaPalette palette = RihlaPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'Votre avis',
                style: AppTypography.title3.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: palette.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                formatDate(review.updatedAt),
                style: AppTypography.caption.copyWith(
                  fontSize: 12,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2),
          Row(
            children: List<Widget>.generate(5, (int index) {
              final bool filled = review.rating >= index + 1;
              return Padding(
                padding: const EdgeInsets.only(right: 2),
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  size: 22,
                  color: palette.starColor,
                ),
              );
            }),
          ),
          if (review.comment.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.x2),
            Text(
              review.comment.trim(),
              style: AppTypography.body.copyWith(
                fontSize: 14.4,
                height: 1.45,
                color: palette.textPrimary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.x2),
          Row(
            children: <Widget>[
              _OwnReviewReactionCount(
                icon: Icons.thumb_up_alt_outlined,
                count: likesCount,
              ),
              const SizedBox(width: 16),
              _OwnReviewReactionCount(
                icon: Icons.thumb_down_alt_outlined,
                count: dislikesCount,
              ),
              if (onOpenReplies != null && repliesCount > 0) ...<Widget>[
                const Spacer(),
                TextButton.icon(
                  onPressed: onOpenReplies,
                  icon: const Icon(Icons.forum_outlined, size: 16),
                  label: Text(
                    '$repliesCount réponse${repliesCount > 1 ? 's' : ''}',
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: palette.brandPrimary,
                    minimumSize: const Size(36, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: AppTypography.caption.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Modifier'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Supprimer'),
                  style: TextButton.styleFrom(
                    foregroundColor: RihlaPalette.of(context).dangerForeground,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OwnReviewReactionCount extends StatelessWidget {
  const _OwnReviewReactionCount({required this.icon, required this.count});

  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    final RihlaPalette palette = RihlaPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 16, color: palette.textSecondary),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: AppTypography.caption.copyWith(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: palette.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ReviewRepliesSheet extends StatefulWidget {
  const _ReviewRepliesSheet({
    required this.review,
    required this.ratingService,
    required this.connectivity,
    required this.formatDate,
    this.autofocusInput = false,
  });

  final PublicReview review;
  final RatingService ratingService;
  final ConnectivityService connectivity;
  final String Function(DateTime) formatDate;
  final bool autofocusInput;

  @override
  State<_ReviewRepliesSheet> createState() => _ReviewRepliesSheetState();
}

class _ReviewRepliesSheetState extends State<_ReviewRepliesSheet> {
  final TextEditingController _replyController = TextEditingController();
  List<PublicReviewReply> _replies = const <PublicReviewReply>[];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadReplies();
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadReplies() async {
    final replies = await widget.ratingService.fetchRepliesForReview(
      widget.review,
    );
    if (!mounted) return;
    setState(() {
      _replies = replies;
      _isLoading = false;
    });
  }

  Future<bool> _ensureOnline(String message) async {
    bool online;
    try {
      online = await widget.connectivity.isOnlineNow().timeout(
        const Duration(seconds: 3),
      );
    } on Object {
      online = true;
    }
    if (!online && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
    return online;
  }

  Future<void> _sendReply() async {
    final comment = _replyController.text.trim();
    if (comment.isEmpty) return;
    if (!await _ensureOnline(
      'Vous êtes hors ligne. Reconnectez-vous pour répondre.',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _isSending = true);
    await widget.ratingService.addReplyToReview(
      review: widget.review,
      comment: comment,
    );
    if (!mounted) return;
    _replyController.clear();
    await _loadReplies();
    if (mounted) setState(() => _isSending = false);
  }

  Future<void> _editReply(PublicReviewReply reply) async {
    if (!await _ensureOnline(
      'Vous êtes hors ligne. Reconnectez-vous pour modifier votre réponse.',
    )) {
      return;
    }
    if (!mounted) return;
    final editController = TextEditingController(text: reply.comment);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Modifier la réponse'),
          content: TextField(
            controller: editController,
            maxLength: SiteReview.maxCommentLength,
            maxLines: 4,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Votre réponse',
              border: OutlineInputBorder(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(editController.text.trim()),
              child: const Text('Enregistrer'),
            ),
          ],
        );
      },
    );
    editController.dispose();
    if (result == null || result.isEmpty || result == reply.comment) return;
    if (!mounted) return;
    final ok = await widget.ratingService.updateReplyComment(
      replyId: reply.id,
      comment: result,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de modifier la réponse.')),
      );
      return;
    }
    await _loadReplies();
  }

  Future<void> _deleteReply(PublicReviewReply reply) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer la réponse ?'),
        content: const Text('Cette réponse sera définitivement supprimée.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!await _ensureOnline(
      'Vous êtes hors ligne. Reconnectez-vous pour supprimer votre réponse.',
    )) {
      return;
    }
    if (!mounted) return;
    final ok = await widget.ratingService.deleteReply(reply.id);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de supprimer la réponse.')),
      );
      return;
    }
    await _loadReplies();
  }

  @override
  Widget build(BuildContext context) {
    final palette = RihlaPalette.of(context);
    final bool canReply = !SessionModeNotifier.isGuest;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Réponses'),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: <Widget>[
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : _replies.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          'Aucune réponse pour le moment.',
                          style: AppTypography.body.copyWith(
                            color: palette.textSecondary,
                          ),
                        ),
                      ),
                    )
                  : Builder(
                      builder: (context) {
                        final String? currentUid = resolveCurrentUid();
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                          itemCount: _replies.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.x2),
                          itemBuilder: (context, index) {
                            final reply = _replies[index];
                            final bool isOwn =
                                currentUid != null &&
                                currentUid.isNotEmpty &&
                                reply.authorUserId == currentUid;
                            return _ReplyTile(
                              reply: reply,
                              formatDate: widget.formatDate,
                              isOwn: isOwn,
                              onEdit: isOwn ? () => _editReply(reply) : null,
                              onDelete: isOwn
                                  ? () => _deleteReply(reply)
                                  : null,
                            );
                          },
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: canReply
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _replyController,
                            autofocus: widget.autofocusInput,
                            maxLength: SiteReview.maxCommentLength,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendReply(),
                            decoration: const InputDecoration(
                              hintText: 'Écrire une réponse',
                              border: OutlineInputBorder(),
                              counterText: '',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: _isSending ? null : _sendReply,
                          tooltip: 'Envoyer la réponse',
                          icon: _isSending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                        ),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Connectez-vous pour répondre.',
                        style: AppTypography.caption.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplyTile extends StatelessWidget {
  const _ReplyTile({
    required this.reply,
    required this.formatDate,
    this.isOwn = false,
    this.onEdit,
    this.onDelete,
  });

  final PublicReviewReply reply;
  final String Function(DateTime) formatDate;
  final bool isOwn;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final palette = RihlaPalette.of(context);
    final author = reply.authorName.isEmpty
        ? 'Voyageur RIHLA'
        : reply.authorName;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: palette.softSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              CircleAvatar(
                radius: 13,
                backgroundColor: palette.brandPrimarySoft,
                child: Text(
                  author.characters.first.toUpperCase(),
                  style: AppTypography.bodyStrong.copyWith(
                    fontSize: 12,
                    color: palette.brandPrimaryOnSoft,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyStrong.copyWith(fontSize: 13.4),
                ),
              ),
              Text(
                formatDate(reply.updatedAt),
                style: AppTypography.caption.copyWith(
                  fontSize: 11.4,
                  color: palette.textSecondary,
                ),
              ),
              if (isOwn) ...<Widget>[
                const SizedBox(width: 2),
                PopupMenuButton<String>(
                  tooltip: 'Modifier ou supprimer',
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  splashRadius: 18,
                  onSelected: (String value) {
                    if (value == 'edit') {
                      onEdit?.call();
                    } else if (value == 'delete') {
                      onDelete?.call();
                    }
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(
                          value: 'edit',
                          child: Row(
                            children: <Widget>[
                              Icon(Icons.edit_outlined, size: 18),
                              SizedBox(width: 10),
                              Text('Modifier'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: <Widget>[
                              Icon(Icons.delete_outline, size: 18),
                              SizedBox(width: 10),
                              Text('Supprimer'),
                            ],
                          ),
                        ),
                      ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            reply.comment,
            style: AppTypography.body.copyWith(
              fontSize: 13.6,
              height: 1.4,
              color: palette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewEditor extends StatelessWidget {
  const _ReviewEditor({
    required this.site,
    required this.existingReview,
    required this.isSaving,
    required this.userRating,
    required this.commentController,
    required this.onRate,
    required this.onSave,
    required this.onCancel,
  });

  final TouristSite site;
  final SiteReview? existingReview;
  final bool isSaving;
  final double? userRating;
  final TextEditingController commentController;
  final ValueChanged<double> onRate;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final RihlaPalette palette = RihlaPalette.of(context);
    final bool hasExisting = existingReview != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            hasExisting ? 'Modifier votre avis' : 'Partagez votre avis',
            style: AppTypography.title3.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Notez ce site et écrivez quelques mots sur votre expérience.',
            style: AppTypography.caption.copyWith(
              fontSize: 12.6,
              color: palette.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          Wrap(
            spacing: 2,
            children: List<Widget>.generate(5, (int index) {
              final int starValue = index + 1;
              final bool selected = (userRating ?? 0) >= starValue;
              return Semantics(
                button: true,
                selected: selected,
                label: 'Noter $starValue sur 5 pour ${site.name}',
                child: IconButton(
                  onPressed: () => onRate(starValue.toDouble()),
                  tooltip: 'Noter $starValue sur 5',
                  icon: Icon(
                    selected ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: palette.starColor,
                    size: 30,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: AppSpacing.x2),
          TextField(
            controller: commentController,
            maxLines: 4,
            maxLength: SiteReview.maxCommentLength,
            decoration: const InputDecoration(
              hintText: 'Décrivez votre expérience (optionnel)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          Row(
            children: <Widget>[
              Expanded(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: isSaving ? 0.6 : 1,
                  child: FilledButton.icon(
                    onPressed: isSaving ? null : onSave,
                    icon: isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      isSaving
                          ? 'Envoi…'
                          : (hasExisting ? 'Mettre à jour' : 'Publier'),
                    ),
                  ),
                ),
              ),
              if (hasExisting) ...<Widget>[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: isSaving ? null : onCancel,
                  child: const Text('Annuler'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
