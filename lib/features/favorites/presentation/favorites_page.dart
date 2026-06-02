import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rihla/core/services/favorites_service.dart';
import 'package:rihla/data/models/tourist_site.dart';
import 'package:rihla/data/repositories/site_repository.dart';
import 'package:rihla/features/shared/widgets/profile_collection_widgets.dart';
import 'package:rihla/features/sites/presentation/site_detail_page.dart';
import 'package:rihla/theme/spacing.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({
    super.key,
    FavoritesService? favoritesService,
    SiteRepository? repository,
  }) : _favoritesService = favoritesService,
       _repository = repository;

  final FavoritesService? _favoritesService;
  final SiteRepository? _repository;

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late final FavoritesService _favoritesService =
      widget._favoritesService ?? FavoritesService();
  late final SiteRepository _repository =
      widget._repository ?? SiteRepository.instance;

  StreamSubscription<void>? _favoritesSubscription;
  List<TouristSite> _allSites = [];
  List<TouristSite> _favoriteSites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSitesAndFavorites();
    _favoritesSubscription = FavoritesService.changes.listen((_) {
      _loadFavorites();
    });
  }

  @override
  void dispose() {
    _favoritesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSitesAndFavorites() async {
    final sites = await _repository.getSites();
    if (!mounted) return;
    setState(() {
      _allSites = sites;
    });
    await _loadFavorites();
  }

  Future<void> _refresh() async {
    await _loadSitesAndFavorites();
  }

  Future<void> _loadFavorites() async {
    if (_allSites.isEmpty) {
      _allSites = await _repository.getSites();
    }

    final favoriteIds = await _favoritesService.getFavorites();
    final favorites = _allSites
        .where((site) => favoriteIds.contains(site.id))
        .toList();

    if (!mounted) return;
    setState(() {
      _favoriteSites = favorites;
      _isLoading = false;
    });
  }

  Future<void> _removeFavorite(String siteId) async {
    await _favoritesService.removeFavorite(siteId);
  }

  void _openSite(TouristSite site) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => SiteDetailPage(site: site)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return ProfileCollectionPage(
      title: 'Mes favoris',
      subtitle: 'Vos lieux préférés, toujours à portée de main',
      countText:
          '${_favoriteSites.length} lieu${_favoriteSites.length > 1 ? 'x' : ''} sauvegardé${_favoriteSites.length > 1 ? 's' : ''}',
      icon: Icons.favorite_rounded,
      onRefresh: _refresh,
      child: _favoriteSites.isEmpty
          ? const ProfileCollectionEmptyState(
              icon: Icons.favorite_border_rounded,
              title: 'Aucun favori pour le moment',
              message:
                  'Ajoutez des destinations à vos favoris pour les retrouver ici rapidement.',
            )
          : Column(
              children: _favoriteSites.map((site) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.x3),
                  child: ProfileDestinationRow(
                    site: site,
                    onTap: () => _openSite(site),
                    trailingIcon: Icons.favorite_rounded,
                    onTrailingTap: () => _removeFavorite(site.id),
                  ),
                );
              }).toList(),
            ),
    );
  }
}
