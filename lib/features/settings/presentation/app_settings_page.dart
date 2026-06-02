import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:rihla/core/services/profile_photo_service.dart';
import 'package:rihla/core/services/profile_service.dart';
import 'package:rihla/core/services/supabase_auth_service.dart';
import 'package:rihla/core/theme/rihla_palette.dart';
import 'package:rihla/features/settings/presentation/about_rihla_page.dart';
import 'package:rihla/features/settings/presentation/account_settings_page.dart';
import 'package:rihla/features/settings/presentation/appearance_settings_page.dart';
import 'package:rihla/features/settings/presentation/privacy_settings_page.dart';
import 'package:rihla/features/settings/presentation/settings_icon_box.dart';
import 'package:rihla/features/settings/presentation/useful_numbers_page.dart';
import 'package:rihla/theme/spacing.dart';
import 'package:rihla/theme/typography.dart';
import 'package:url_launcher/url_launcher.dart';

class AppSettingsPage extends StatelessWidget {
  const AppSettingsPage({
    super.key,
    this.isGuestMode = false,
    ProfileService? profileService,
    ProfilePhotoService? profilePhotoService,
    SupabaseAuthService? authService,
  }) : _profileService = profileService,
       _profilePhotoService = profilePhotoService,
       _authService = authService;

  final bool isGuestMode;
  final ProfileService? _profileService;
  final ProfilePhotoService? _profilePhotoService;
  final SupabaseAuthService? _authService;

  Future<String> _versionLabel() async {
    final info = await PackageInfo.fromPlatform();
    final build = info.buildNumber.isEmpty ? '' : '+${info.buildNumber}';
    return '${info.version}$build';
  }

  void _openAbout(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AboutRihlaPage()));
  }

  void _openUsefulNumbers(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const UsefulNumbersPage()));
  }

  Future<void> _openSupportEmail(BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@rihla.app',
      queryParameters: <String, String>{'subject': 'Support RIHLA'},
    );

    if (!await launchUrl(emailUri) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'ouvrir l\'email de support.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final RihlaPalette palette = RihlaPalette.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Paramètres',
          style: AppTypography.title3.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: <Widget>[
          if (!isGuestMode) ...<Widget>[
            _SectionHeader(label: 'Compte'),
            _SettingsGroup(
              children: <Widget>[
                _SettingsTile(
                  icon: Icons.manage_accounts_outlined,
                  title: 'Compte',
                  subtitle: 'Pseudo, email, mot de passe, suppression',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => AccountSettingsPage(
                          profileService: _profileService,
                          profilePhotoService: _profilePhotoService,
                          authService: _authService,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.x4),
          ],
          _SectionHeader(label: 'Préférences'),
          _SettingsGroup(
            children: <Widget>[
              _SettingsTile(
                icon: Icons.palette_outlined,
                title: 'Apparence',
                subtitle: 'Mode clair, sombre ou système',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AppearanceSettingsPage(
                        profileService: _profileService,
                      ),
                    ),
                  );
                },
              ),
              Divider(height: 1, color: palette.divider),
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Confidentialité',
                subtitle: 'Permissions et données',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PrivacySettingsPage(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x4),
          _SectionHeader(label: 'Assistance'),
          _SettingsGroup(
            children: <Widget>[
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                title: 'À propos de RIHLA',
                subtitleWidget: FutureBuilder<String>(
                  future: _versionLabel(),
                  builder: (context, snapshot) {
                    return Text(
                      snapshot.hasData ? 'Version ${snapshot.data}' : 'Version',
                      style: AppTypography.caption.copyWith(
                        fontSize: 12.5,
                        color: palette.textSecondary,
                      ),
                    );
                  },
                ),
                onTap: () => _openAbout(context),
              ),
              Divider(height: 1, color: palette.divider),
              _SettingsTile(
                icon: Icons.local_police_outlined,
                title: 'Numéros utiles',
                subtitle: 'Police, Protection civile, Gendarmerie',
                onTap: () => _openUsefulNumbers(context),
              ),
              Divider(height: 1, color: palette.divider),
              _SettingsTile(
                icon: Icons.support_agent_rounded,
                title: 'Centre d\'aide',
                subtitle: 'Contacter le support par email',
                onTap: () => _openSupportEmail(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final RihlaPalette palette = RihlaPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, AppSpacing.x2),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.caption.copyWith(
          fontSize: 11.5,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
          color: palette.textSecondary,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final RihlaPalette palette = RihlaPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.divider),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.subtitleWidget,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final RihlaPalette palette = RihlaPalette.of(context);
    return ListTile(
      minLeadingWidth: 38,
      leading: SettingsIconBox(icon: icon),
      title: Text(title),
      subtitle:
          subtitleWidget ??
          (subtitle == null
              ? null
              : Text(
                  subtitle!,
                  style: AppTypography.caption.copyWith(
                    fontSize: 12.5,
                    color: palette.textSecondary,
                  ),
                )),
      trailing: Icon(Icons.chevron_right_rounded, color: palette.textSecondary),
      onTap: onTap,
    );
  }
}
