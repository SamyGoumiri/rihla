import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rihla/core/theme/rihla_palette.dart';
import 'package:rihla/features/settings/presentation/settings_icon_box.dart';
import 'package:rihla/theme/spacing.dart';
import 'package:rihla/theme/typography.dart';

class PrivacySettingsPage extends StatelessWidget {
  const PrivacySettingsPage({super.key});

  Future<void> _openSystemSettings(BuildContext context) async {
    final opened = await Geolocator.openAppSettings();
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible d\'ouvrir les réglages système. Ouvrez les paramètres Android puis Applications > RIHLA.',
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
          'Confidentialité',
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
                  'Vos données',
                  style: AppTypography.title3.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  'RIHLA garde une copie locale de vos favoris, historique, avis et préférences. Une fois connecté, ces données sont synchronisées avec votre compte. La photo de profil est aussi envoyée vers le stockage sécurisé de l\'application pour l\'affichage public de votre profil et de vos avis.',
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
          Text(
            'Permissions système',
            style: AppTypography.title3.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          Container(
            decoration: BoxDecoration(
              color: palette.cardSurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.divider),
            ),
            child: Column(
              children: <Widget>[
                _PermissionTile(
                  icon: Icons.location_on_outlined,
                  title: 'Localisation',
                  subtitle: 'Carte, itinéraires et sites proches.',
                  onOpenSettings: () => _openSystemSettings(context),
                ),
                Divider(height: 1, color: palette.divider),
                _PermissionTile(
                  icon: Icons.photo_library_outlined,
                  title: 'Photos',
                  subtitle: 'Choisir une photo de profil.',
                  onOpenSettings: () => _openSystemSettings(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onOpenSettings,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minLeadingWidth: 38,
      leading: SettingsIconBox(icon: icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: TextButton(
        onPressed: onOpenSettings,
        child: const Text('Réglages'),
      ),
    );
  }
}
