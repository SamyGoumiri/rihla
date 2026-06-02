import 'package:rihla/core/constants/categories.dart';
import 'package:rihla/core/services/history_service.dart';
import 'package:rihla/data/models/tourist_site.dart';

class RecommendationConfig {
  const RecommendationConfig({
    this.favoriteCategoryWeight = 3.0,
    this.highRatingCategoryWeight = 2.0,
    this.historyCategoryWeight = 1.0,
    this.favoriteCityBonus = 0.5,
    this.highRatingThreshold = 4.0,
    this.minFavoritesForPersonalization = 2,
    this.minHistoryForPersonalization = 3,
  });

  final double favoriteCategoryWeight;
  final double highRatingCategoryWeight;
  final double historyCategoryWeight;
  final double favoriteCityBonus;
  final double highRatingThreshold;
  final int minFavoritesForPersonalization;
  final int minHistoryForPersonalization;

  static const RecommendationConfig defaults = RecommendationConfig();
}

class RecommendationService {
  const RecommendationService({this.config = RecommendationConfig.defaults});

  final RecommendationConfig config;

  List<TouristSite> recommendFor({
    required List<TouristSite> sites,
    required Set<String> favoriteIds,
    required List<HistoryEntry> history,
    required Map<String, double> ratings,
    int limit = 5,
  }) {
    if (sites.isEmpty || limit <= 0) {
      return const <TouristSite>[];
    }

    final excluded = <String>{
      ...favoriteIds,
      ...ratings.entries
          .where((e) => e.value >= config.highRatingThreshold)
          .map((e) => e.key),
    };

    final hasEnoughSignal =
        favoriteIds.length >= config.minFavoritesForPersonalization ||
        history.length >= config.minHistoryForPersonalization;

    final availableSites = sites
        .where((s) => !excluded.contains(s.id))
        .toList();

    if (!hasEnoughSignal) {
      return _fallbackBestRated(availableSites, limit);
    }

    final byId = <String, TouristSite>{for (final site in sites) site.id: site};

    final categoryScore = <SiteCategory, double>{};
    final cityScore = <String, double>{};

    for (final id in favoriteIds) {
      final site = byId[id];
      if (site == null) continue;
      categoryScore[site.category] =
          (categoryScore[site.category] ?? 0) + config.favoriteCategoryWeight;
      cityScore[site.city] =
          (cityScore[site.city] ?? 0) + config.favoriteCityBonus;
    }

    ratings.forEach((siteId, rating) {
      if (rating < config.highRatingThreshold) return;
      final site = byId[siteId];
      if (site == null) return;
      categoryScore[site.category] =
          (categoryScore[site.category] ?? 0) + config.highRatingCategoryWeight;
    });

    final seenInHistory = <String>{};
    for (final entry in history) {
      if (!seenInHistory.add(entry.siteId)) continue;
      final site = byId[entry.siteId];
      if (site == null) continue;
      categoryScore[site.category] =
          (categoryScore[site.category] ?? 0) + config.historyCategoryWeight;
    }

    final scored = <_ScoredSite>[];
    for (final site in sites) {
      if (excluded.contains(site.id)) continue;
      final score =
          (categoryScore[site.category] ?? 0) + (cityScore[site.city] ?? 0);
      if (score <= 0) continue;
      scored.add(_ScoredSite(site, score));
    }

    if (scored.isEmpty) {
      return _fallbackBestRated(availableSites, limit);
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return (b.site.averageRating ?? 0).compareTo(a.site.averageRating ?? 0);
    });

    return scored.take(limit).map((entry) => entry.site).toList();
  }

  List<TouristSite> _fallbackBestRated(List<TouristSite> sites, int limit) {
    final rated = sites.where((site) => site.reviewCount > 0).toList();
    if (rated.isNotEmpty) {
      rated.sort((a, b) {
        final byRating = (b.averageRating ?? 0).compareTo(a.averageRating ?? 0);
        if (byRating != 0) return byRating;
        final byCount = b.reviewCount.compareTo(a.reviewCount);
        if (byCount != 0) return byCount;
        return a.name.compareTo(b.name);
      });
      return rated.take(limit).toList();
    }

    final sorted = [...sites]
      ..sort((a, b) => _stableRandomRank(a).compareTo(_stableRandomRank(b)));
    return sorted.take(limit).toList();
  }

  int _stableRandomRank(TouristSite site) {
    final source = '${site.id}|${site.name}|${site.city}';
    var hash = 0x811c9dc5;
    for (final unit in source.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}

class _ScoredSite {
  const _ScoredSite(this.site, this.score);
  final TouristSite site;
  final double score;
}
