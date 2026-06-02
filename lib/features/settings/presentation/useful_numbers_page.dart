import 'package:flutter/material.dart';
import 'package:rihla/core/theme/rihla_palette.dart';
import 'package:rihla/theme/spacing.dart';
import 'package:rihla/theme/typography.dart';
import 'package:url_launcher/url_launcher.dart';

class UsefulNumbersPage extends StatelessWidget {
  const UsefulNumbersPage({super.key});

  static final List<_UsefulContact> _contacts = <_UsefulContact>[
    const _UsefulContact(
      icon: Icons.local_police_outlined,
      title: 'Police',
      subtitle: 'Urgences, sécurité publique en zone urbaine',
      number: '17',
      highlight: true,
    ),
    const _UsefulContact(
      icon: Icons.local_fire_department_outlined,
      title: 'Protection civile',
      subtitle: 'Pompiers, ambulances, secours d\'urgence',
      number: '14',
    ),
    const _UsefulContact(
      icon: Icons.shield_outlined,
      title: 'Gendarmerie nationale',
      subtitle: 'Zones rurales, autoroutes, hors-ville',
      number: '1055',
    ),
  ];

  Future<void> _launchContact(
    BuildContext context,
    _UsefulContact contact,
  ) async {
    final Uri uri = Uri(scheme: 'tel', path: contact.number);
    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    ).catchError((_) => false);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible de lancer l\'appel. Composez ${contact.number} manuellement.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = RihlaPalette.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Numéros utiles',
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.cardSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'En cas de besoin',
                  style: AppTypography.title3.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  'Numéros gratuits en Algérie pour les situations d\'urgence '
                  'et les besoins de sécurité les plus courants.',
                  style: AppTypography.body.copyWith(
                    fontSize: 14,
                    height: 1.45,
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x4),
          for (final contact in _contacts)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ContactTile(
                contact: contact,
                onTap: () => _launchContact(context, contact),
              ),
            ),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact, required this.onTap});

  final _UsefulContact contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = RihlaPalette.of(context);
    final accent = contact.highlight
        ? palette.brandPrimary
        : palette.textSecondary;
    return Material(
      color: palette.cardSurface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: contact.highlight
                  ? palette.brandPrimary.withValues(alpha: 0.45)
                  : palette.divider,
              width: contact.highlight ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(contact.icon, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      contact.title,
                      style: AppTypography.bodyStrong.copyWith(
                        fontSize: 15,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      contact.subtitle,
                      style: AppTypography.caption.copyWith(
                        fontSize: 12.6,
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.phone_rounded, size: 16, color: accent),
                    const SizedBox(width: 6),
                    Text(
                      contact.number,
                      style: AppTypography.bodyStrong.copyWith(
                        fontSize: 13.5,
                        color: accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UsefulContact {
  const _UsefulContact({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.number,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String number;
  final bool highlight;
}
