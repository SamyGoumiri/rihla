import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:rihla/core/constants/categories.dart';
import 'package:rihla/core/services/favorites_service.dart';
import 'package:rihla/core/services/history_service.dart';
import 'package:rihla/core/services/rating_service.dart';
import 'package:rihla/core/services/recommendation_service.dart';
import 'package:rihla/core/theme/rihla_palette.dart';
import 'package:rihla/core/widgets/app_site_image.dart';
import 'package:rihla/core/widgets/site_rating_label.dart';
import 'package:rihla/data/models/tourist_site.dart';
import 'package:rihla/data/repositories/site_repository.dart';
import 'package:rihla/features/discover/presentation/section_empty.dart';
import 'package:rihla/features/sites/presentation/site_detail_page.dart';
import 'package:rihla/theme/spacing.dart';
import 'package:rihla/theme/typography.dart';

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({
    super.key,
    this.isGuestMode = false,
    SiteRepository? repository,
    FavoritesService? favoritesService,
    HistoryService? historyService,
    RatingService? ratingService,
    RecommendationService? recommendationService,
  }) : _repository = repository,
       _favoritesService = favoritesService,
       _historyService = historyService,
       _ratingService = ratingService,
       _recommendationService = recommendationService;

  final bool isGuestMode;
  final SiteRepository? _repository;
  final FavoritesService? _favoritesService;
  final HistoryService? _historyService;
  final RatingService? _ratingService;
  final RecommendationService? _recommendationService;

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  late final SiteRepository _repository =
      widget._repository ?? SiteRepository.instance;
  late final FavoritesService _favoritesService =
      widget._favoritesService ?? FavoritesService();
  late final HistoryService _historyService =
      widget._historyService ?? HistoryService();
  late final RatingService _ratingService =
      widget._ratingService ?? RatingService();
  late final RecommendationService _recommendationService =
      widget._recommendationService ?? const RecommendationService();
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  StreamSubscription<void>? _favoritesSubscription;
  SiteCategory? _selectedCategory;

  Set<String> _favorites = <String>{};
  List<TouristSite> _allSites = <TouristSite>[];
  List<TouristSite> _recommendations = <TouristSite>[];
  bool _isPersonalizedReco = false;
  bool _hasRecommendationSignal = false;
  bool _isLoadingSites = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSites();
    _loadFavorites();
    _favoritesSubscription = FavoritesService.changes.listen((_) {
      _loadFavorites();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _favoritesSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSites({bool forceRefresh = false}) async {
    try {
      final sites = await _repository.getSites(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _allSites = sites;
        _isLoadingSites = false;
      });
      await _loadRecommendations();
    } catch (error, stackTrace) {
      developer.log(
        'Failed to load discover sites: $error',
        name: 'DiscoverPage',
        error: error,
        stackTrace: stackTrace,
        level: 1000,
      );
      if (!mounted) return;
      setState(() {
        _isLoadingSites = false;
      });
    }
  }

  Future<void> _loadFavorites() async {
    final favorites = await _favoritesService.getFavorites();
    if (!mounted) return;
    setState(() {
      _favorites = favorites.toSet();
    });
  }

  Future<void> _loadRecommendations() async {
    final history = await _historyService.getHistory();
    final ratings = await _ratingService.getRatings();
    final favorites = await _favoritesService.getFavorites();
    final favSet = favorites.toSet();
    final hasSignal =
        favSet.isNotEmpty || history.isNotEmpty || ratings.isNotEmpty;
    final personalized =
        favSet.length >=
            _recommendationService.config.minFavoritesForPersonalization ||
        history.length >=
            _recommendationService.config.minHistoryForPersonalization;
    final recommendations = _recommendationService.recommendFor(
      sites: _allSites,
      favoriteIds: favSet,
      history: history,
      ratings: ratings,
      limit: 6,
    );

    if (!mounted) return;
    setState(() {
      _recommendations = recommendations;
      _hasRecommendationSignal = hasSignal;
      _isPersonalizedReco = personalized;
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _isLoadingSites = true;
    });
    await _loadSites(forceRefresh: true);
    await _loadFavorites();
  }

  void _toggleFavorite(String siteId) {
    if (_favorites.contains(siteId)) {
      _favoritesService.removeFavorite(siteId);
    } else {
      _favoritesService.addFavorite(siteId);
    }
  }

  void _openSite(TouristSite site) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => SiteDetailPage(site: site)));
  }

  List<TouristSite> _filteredSites() {
    final query = _searchQuery;
    return _allSites.where((TouristSite site) {
      final bool matchesQuery =
          query.isEmpty ||
          site.name.toLowerCase().contains(query) ||
          site.city.toLowerCase().contains(query) ||
          site.description.toLowerCase().contains(query) ||
          site.address.toLowerCase().contains(query);
      final bool matchesCategory =
          _selectedCategory == null ||
          site.hasCategorySlug(_selectedCategory!.name);
      return matchesQuery && matchesCategory;
    }).toList();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      final String nextQuery = value.trim().toLowerCase();
      if (nextQuery == _searchQuery) return;
      setState(() {
        _searchQuery = nextQuery;
      });
    });
  }

  String _greetingTitle() => 'Explorez l\'Algérie';

  String _catalogIssueMessage() {
    switch (SiteRepository.dataSourceStatus.value) {
      case SiteDataSourceStatus.empty:
        return 'Catalogue vide.';
      case SiteDataSourceStatus.unavailable:
        return 'Connexion indisponible : impossible de charger le catalogue.';
      case SiteDataSourceStatus.cloud:
        return '';
    }
  }

  String _catalogSubtitle(int count) {
    final String plural = count > 1 ? 's' : '';
    if (_selectedCategory == null && _searchQuery.isEmpty) {
      return '$count site$plural au catalogue';
    }
    return '$count résultat$plural';
  }

  String _recommendationSubtitle() {
    if (_hasRecommendationSignal && _isPersonalizedReco) {
      return 'Basées sur vos favoris et consultations';
    }
    final bool hasRatedRecommendation = _recommendations.any(
      (site) => site.reviewCount > 0,
    );
    if (hasRatedRecommendation) {
      return 'Les sites les mieux notés du catalogue';
    }
    return 'Sélection du catalogue';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingSites) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final RihlaPalette palette = RihlaPalette.of(context);
    final List<TouristSite> filtered = _filteredSites();
    final bool hasCatalogIssue =
        SiteRepository.dataSourceStatus.value != SiteDataSourceStatus.cloud;
    final bool showRecommendations = _recommendations.isNotEmpty;

    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: palette.brandPrimary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: <Widget>[
              _DiscoverHeader(title: _greetingTitle()),
              if (hasCatalogIssue) ...<Widget>[
                const SizedBox(height: AppSpacing.x3),
                _CatalogIssueBanner(
                  palette: palette,
                  message: _catalogIssueMessage(),
                ),
              ],
              if (showRecommendations) ...<Widget>[
                const SizedBox(height: AppSpacing.x4),
                _CompactSectionTitle(
                  title: 'Recommandations',
                  subtitle: _recommendationSubtitle(),
                ),
                const SizedBox(height: AppSpacing.x2),
                _PersonalRecoStrip(
                  destinations: _recommendations,
                  favoriteIds: _favorites,
                  isGuest: widget.isGuestMode,
                  onOpen: _openSite,
                  onToggleFavorite: widget.isGuestMode ? null : _toggleFavorite,
                ),
              ],
              const SizedBox(height: AppSpacing.x4),
              _DiscoverSearchField(
                searchController: _searchController,
                onSearchChanged: _onSearchChanged,
              ),
              const SizedBox(height: AppSpacing.x3),
              _CategoryRow(
                selected: _selectedCategory,
                onSelect: (cat) {
                  setState(() {
                    _selectedCategory = _selectedCategory == cat ? null : cat;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.x4),
              _CompactSectionTitle(
                title: 'À découvrir',
                subtitle: _catalogSubtitle(filtered.length),
              ),
              const SizedBox(height: AppSpacing.x2),
              if (filtered.isEmpty)
                const SectionEmpty(
                  message:
                      'Aucun site ne correspond à votre recherche pour le moment.',
                )
              else
                _DiscoverGrid(
                  destinations: filtered,
                  favoriteIds: _favorites,
                  isGuest: widget.isGuestMode,
                  onOpen: _openSite,
                  onToggleFavorite: widget.isGuestMode ? null : _toggleFavorite,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiscoverHeader extends StatelessWidget {
  const _DiscoverHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final RihlaPalette palette = RihlaPalette.of(context);
    return Text(
      title,
      maxLines: 2,
      style: AppTypography.title2.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: palette.textPrimary,
        height: 1.15,
      ),
    );
  }
}

class _DiscoverSearchField extends StatelessWidget {
  const _DiscoverSearchField({
    required this.searchController,
    required this.onSearchChanged,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    final RihlaPalette palette = RihlaPalette.of(context);
    return TextField(
      controller: searchController,
      onChanged: onSearchChanged,
      style: AppTypography.body.copyWith(
        fontSize: 14.4,
        color: palette.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: 'Rechercher un lieu, une ville',
        hintStyle: AppTypography.caption.copyWith(
          fontSize: 13,
          color: palette.textSecondary,
        ),
        prefixIcon: Icon(Icons.search_rounded, color: palette.textSecondary),
        filled: true,
        fillColor: palette.cardSurface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.brandPrimary, width: 1.3),
        ),
      ),
    );
  }
}

class _CompactSectionTitle extends StatelessWidget {
  const _CompactSectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final RihlaPalette palette = RihlaPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: AppTypography.title3.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: palette.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: AppTypography.caption.copyWith(
            fontSize: 12.6,
            color: palette.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _CatalogIssueBanner extends StatelessWidget {
  const _CatalogIssueBanner({required this.palette, required this.message});

  final RihlaPalette palette;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.warningBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.warningBorder),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.info_outline_rounded, color: palette.warningForeground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: palette.warningForeground),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.selected, required this.onSelect});

  final SiteCategory? selected;
  final ValueChanged<SiteCategory?> onSelect;

  @override
  Widget build(BuildContext context) {
    final RihlaPalette palette = RihlaPalette.of(context);
    final List<_CategoryChipData> chips = <_CategoryChipData>[
      const _CategoryChipData(
        category: null,
        label: 'Tous',
        icon: Icons.grid_view_rounded,
      ),
      for (final cat in SiteCategory.values)
        _CategoryChipData(category: cat, label: cat.label, icon: cat.icon),
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final chip = chips[index];
          final bool isActive = selected == chip.category;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () => onSelect(chip.category),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isActive ? palette.brandPrimary : palette.cardSurface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isActive ? palette.brandPrimary : palette.divider,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      chip.icon,
                      size: 14,
                      color: isActive ? Colors.white : palette.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      chip.label,
                      style: AppTypography.caption.copyWith(
                        fontSize: 12.6,
                        fontWeight: FontWeight.w700,
                        color: isActive ? Colors.white : palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CategoryChipData {
  const _CategoryChipData({
    required this.category,
    required this.label,
    required this.icon,
  });

  final SiteCategory? category;
  final String label;
  final IconData icon;
}

class _PersonalRecoStrip extends StatelessWidget {
  const _PersonalRecoStrip({
    required this.destinations,
    required this.favoriteIds,
    required this.isGuest,
    required this.onOpen,
    required this.onToggleFavorite,
  });

  final List<TouristSite> destinations;
  final Set<String> favoriteIds;
  final bool isGuest;
  final ValueChanged<TouristSite> onOpen;
  final ValueChanged<String>? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: destinations.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (BuildContext context, int index) {
          final site = destinations[index];
          final toggle = onToggleFavorite;
          return _CompactDestinationCard(
            site: site,
            isFavorite: favoriteIds.contains(site.id),
            isGuest: isGuest,
            onOpen: () => onOpen(site),

            onToggleFavorite: toggle == null ? null : () => toggle(site.id),
          );
        },
      ),
    );
  }
}

class _CompactDestinationCard extends StatelessWidget {
  const _CompactDestinationCard({
    required this.site,
    required this.isFavorite,
    required this.onOpen,
    this.onToggleFavorite,
    this.isGuest = false,
  });

  final TouristSite site;
  final bool isFavorite;
  final VoidCallback onOpen;
  final VoidCallback? onToggleFavorite;
  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onOpen,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: <Widget>[
                Positioned.fill(child: AppSiteImagePlaceholder(site: site)),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.black.withValues(alpha: 0.05),
                          Colors.black.withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                  ),
                ),
                if (onToggleFavorite != null)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Tooltip(
                      message: isGuest
                          ? 'Connectez-vous pour ajouter aux favoris'
                          : (isFavorite
                                ? 'Retirer des favoris'
                                : 'Ajouter aux favoris'),
                      child: Material(
                        color: Colors.black.withValues(
                          alpha: isGuest ? 0.22 : 0.32,
                        ),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onToggleFavorite,
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: Icon(
                              isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: Colors.white.withValues(
                                alpha: isGuest ? 0.7 : 1,
                              ),
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        site.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyStrong.copyWith(
                          fontSize: 15.2,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.location_on_outlined,
                            color: Colors.white,
                            size: 13,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              site.city,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                fontSize: 11.8,
                                color: Colors.white.withValues(alpha: 0.92),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SiteRatingLabel(
                            rating: site.averageRating,
                            onDark: true,
                            fontSize: 11.8,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DiscoverGrid extends StatelessWidget {
  const _DiscoverGrid({
    required this.destinations,
    required this.favoriteIds,
    required this.isGuest,
    required this.onOpen,
    required this.onToggleFavorite,
  });

  final List<TouristSite> destinations;
  final Set<String> favoriteIds;
  final bool isGuest;
  final ValueChanged<TouristSite> onOpen;
  final ValueChanged<String>? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final RihlaPalette palette = RihlaPalette.of(context);
    return Column(
      children: List<Widget>.generate(destinations.length, (int index) {
        final site = destinations[index];
        final toggle = onToggleFavorite;
        return Padding(
          padding: EdgeInsets.only(
            bottom: index == destinations.length - 1 ? 0 : 10,
          ),
          child: _DiscoverRow(
            site: site,
            isFavorite: favoriteIds.contains(site.id),
            palette: palette,
            onOpen: () => onOpen(site),
            onToggleFavorite: toggle == null ? null : () => toggle(site.id),
          ),
        );
      }),
    );
  }
}

class _DiscoverRow extends StatelessWidget {
  const _DiscoverRow({
    required this.site,
    required this.isFavorite,
    required this.palette,
    required this.onOpen,
    this.onToggleFavorite,
  });

  final TouristSite site;
  final bool isFavorite;
  final RihlaPalette palette;
  final VoidCallback onOpen;
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: palette.cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.divider),
          ),
          padding: const EdgeInsets.all(10),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: AppSiteImagePlaceholder(site: site),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      site.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyStrong.copyWith(
                        fontSize: 14.6,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      site.city,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        fontSize: 12.4,
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        Icon(
                          site.category.icon,
                          size: 13,
                          color: palette.brandPrimary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          site.category.label,
                          style: AppTypography.caption.copyWith(
                            fontSize: 11.6,
                            fontWeight: FontWeight.w700,
                            color: palette.brandPrimary,
                          ),
                        ),
                        const Spacer(),
                        SiteRatingLabel(rating: site.averageRating),
                      ],
                    ),
                  ],
                ),
              ),
              if (onToggleFavorite != null)
                IconButton(
                  onPressed: onToggleFavorite,
                  tooltip: isFavorite
                      ? 'Retirer des favoris'
                      : 'Ajouter aux favoris',
                  icon: Icon(
                    isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: palette.brandPrimary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppSiteImagePlaceholder extends StatelessWidget {
  const AppSiteImagePlaceholder({super.key, required this.site});

  final TouristSite site;

  @override
  Widget build(BuildContext context) {
    final RihlaPalette palette = RihlaPalette.of(context);
    return AppSiteImage(
      imagePath: site.imageUrl,
      fit: BoxFit.cover,
      fallback: Container(
        color: palette.softSurface,
        alignment: Alignment.center,
        child: Icon(
          Icons.image_not_supported_outlined,
          color: palette.textSecondary,
          size: 28,
        ),
      ),
    );
  }
}
