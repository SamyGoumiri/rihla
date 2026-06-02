import 'package:flutter/material.dart';
import 'package:rihla/core/constants/categories.dart';
import 'package:rihla/core/theme/rihla_palette.dart';
import 'package:rihla/core/widgets/app_site_image.dart';
import 'package:rihla/data/models/tourist_site.dart';
import 'package:rihla/theme/spacing.dart';
import 'package:rihla/theme/typography.dart';

class ProfileCollectionPage extends StatelessWidget {
  const ProfileCollectionPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.countText,
    required this.icon,
    required this.onRefresh,
    required this.child,
  });

  final String title;
  final String subtitle;
  final String countText;
  final IconData icon;
  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = RihlaPalette.of(context);
    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: onRefresh,
          color: palette.brandPrimary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
            children: <Widget>[
              _TopCard(
                title: title,
                subtitle: subtitle,
                countText: countText,
                icon: icon,
              ),
              const SizedBox(height: AppSpacing.x4),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileCollectionEmptyState extends StatelessWidget {
  const ProfileCollectionEmptyState({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = RihlaPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 22),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: palette.brandPrimarySoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: palette.brandPrimaryOnSoft, size: 28),
          ),
          const SizedBox(height: AppSpacing.x3),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.title3.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              fontSize: 13.2,
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileDestinationRow extends StatelessWidget {
  const ProfileDestinationRow({
    super.key,
    required this.site,
    required this.onTap,
    this.trailingIcon,
    this.onTrailingTap,
    this.badgeText,
  });

  final TouristSite site;
  final VoidCallback onTap;
  final IconData? trailingIcon;
  final VoidCallback? onTrailingTap;
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    final palette = RihlaPalette.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: palette.cardSurface,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Row(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AppSiteImage(
                    imagePath: site.imageUrl,
                    width: 84,
                    height: 84,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        site.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyStrong.copyWith(
                          fontSize: 15.5,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        site.city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          fontSize: 12.7,
                          color: palette.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x2),
                      Row(
                        children: <Widget>[
                          Icon(
                            site.category.icon,
                            size: 15,
                            color: palette.brandPrimary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            site.category.label,
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w700,
                              color: palette.brandPrimary,
                            ),
                          ),
                          if (badgeText != null) ...<Widget>[
                            const SizedBox(width: AppSpacing.x2),
                            Text(
                              badgeText!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                fontSize: 12,
                                color: palette.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.x2),
                InkWell(
                  onTap: onTrailingTap ?? onTap,
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      trailingIcon ?? Icons.chevron_right_rounded,
                      color: palette.brandPrimary,
                      size: 22,
                    ),
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

class _TopCard extends StatelessWidget {
  const _TopCard({
    required this.title,
    required this.subtitle,
    required this.countText,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final String countText;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = RihlaPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: palette.brandPrimarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: palette.brandPrimaryOnSoft, size: 28),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: AppTypography.title2.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: palette.textPrimary,
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
                const SizedBox(height: AppSpacing.x1),
                Text(
                  countText,
                  style: AppTypography.caption.copyWith(
                    fontSize: 12.5,
                    color: palette.brandPrimary,
                    fontWeight: FontWeight.w700,
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
