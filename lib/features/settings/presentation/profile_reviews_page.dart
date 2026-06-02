import 'package:flutter/material.dart';
import 'package:rihla/core/services/rating_service.dart';
import 'package:rihla/data/models/site_review.dart';
import 'package:rihla/data/models/tourist_site.dart';
import 'package:rihla/data/repositories/site_repository.dart';
import 'package:rihla/features/shared/widgets/profile_collection_widgets.dart';
import 'package:rihla/features/sites/presentation/site_detail_page.dart';
import 'package:rihla/theme/spacing.dart';

class ProfileReviewsPage extends StatefulWidget {
  const ProfileReviewsPage({
    super.key,
    RatingService? ratingService,
    SiteRepository? repository,
  }) : _ratingService = ratingService,
       _repository = repository;

  final RatingService? _ratingService;
  final SiteRepository? _repository;

  @override
  State<ProfileReviewsPage> createState() => _ProfileReviewsPageState();
}

class _ProfileReviewsPageState extends State<ProfileReviewsPage> {
  late final RatingService _ratingService =
      widget._ratingService ?? RatingService();
  late final SiteRepository _repository =
      widget._repository ?? SiteRepository.instance;

  Map<String, SiteReview> _reviews = <String, SiteReview>{};
  Map<String, TouristSite> _sitesById = <String, TouristSite>{};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    final reviews = await _ratingService.getReviews();
    final sites = await _repository.getSites();
    if (!mounted) return;
    setState(() {
      _reviews = reviews;
      _sitesById = <String, TouristSite>{
        for (final site in sites) site.id: site,
      };
      _isLoading = false;
    });
  }

  void _openSite(TouristSite site) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => SiteDetailPage(site: site)));
  }

  String _formatReviewBadge(SiteReview review) {
    final day = review.updatedAt.day.toString().padLeft(2, '0');
    final month = review.updatedAt.month.toString().padLeft(2, '0');
    return '${review.rating.toStringAsFixed(1)}/5 - $day/$month';
  }

  @override
  Widget build(BuildContext context) {
    final visibleReviews =
        _reviews.values
            .where((review) => _sitesById.containsKey(review.siteId))
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return ProfileCollectionPage(
      title: 'Mes avis',
      subtitle: 'Les sites que vous avez notes et commentes',
      countText:
          '${visibleReviews.length} avis publie${visibleReviews.length > 1 ? 's' : ''}',
      icon: Icons.rate_review_outlined,
      onRefresh: _loadReviews,
      child: visibleReviews.isEmpty
          ? const ProfileCollectionEmptyState(
              icon: Icons.rate_review_outlined,
              title: 'Aucun avis publie',
              message:
                  'Ajoutez un avis depuis une fiche de site pour le retrouver ici.',
            )
          : Column(
              children: visibleReviews.map((review) {
                final site = _sitesById[review.siteId]!;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.x3),
                  child: ProfileDestinationRow(
                    site: site,
                    onTap: () => _openSite(site),
                    badgeText: _formatReviewBadge(review),
                  ),
                );
              }).toList(),
            ),
    );
  }
}
