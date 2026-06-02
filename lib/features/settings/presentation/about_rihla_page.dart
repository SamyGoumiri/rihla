import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:rihla/core/theme/rihla_palette.dart';
import 'package:rihla/theme/spacing.dart';
import 'package:rihla/theme/typography.dart';

class AboutRihlaPage extends StatelessWidget {
  const AboutRihlaPage({super.key});

  Future<String> _versionLabel() async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    final String build = info.buildNumber.isEmpty ? '' : '+${info.buildNumber}';
    return '${info.version}$build';
  }

  @override
  Widget build(BuildContext context) {
    final RihlaPalette palette = RihlaPalette.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('À propos de RIHLA')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: <Widget>[
          _HeroSection(palette: palette),
          const SizedBox(height: AppSpacing.x4),
          FutureBuilder<String>(
            future: _versionLabel(),
            builder: (context, snapshot) {
              return _InfoPanel(
                title: 'Version actuelle',
                children: <Widget>[
                  _InfoLine(
                    icon: Icons.verified_outlined,
                    text: snapshot.hasData ? snapshot.data! : 'Chargement...',
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.x4),
          const _InfoPanel(
            title: 'Support et maintenance',
            children: <Widget>[
              _InfoLine(
                icon: Icons.email_outlined,
                text:
                    'Le support reste accessible depuis les paramètres si vous avez une question ou un retour.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.palette});

  final RihlaPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            palette.cardSurface,
            palette.brandPrimarySoft.withValues(alpha: 0.55),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: palette.brandPrimarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.travel_explore_rounded,
                  color: palette.brandPrimaryOnSoft,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'RIHLA',
                style: AppTypography.title2.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: palette.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          Text(
            'Application mobile touristique pour explorer des sites algériens, organiser un itinéraire et synchroniser favoris, avis et données utiles via Supabase et SQLite.',
            style: AppTypography.body.copyWith(
              height: 1.45,
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final RihlaPalette palette = RihlaPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
            child: Text(
              title,
              style: AppTypography.title3.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: palette.textPrimary,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final RihlaPalette palette = RihlaPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: palette.brandPrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTypography.body.copyWith(
                color: palette.textSecondary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
