import 'package:flutter/material.dart';
import 'package:rihla/core/services/profile_service.dart';
import 'package:rihla/core/theme/rihla_palette.dart';
import 'package:rihla/theme/spacing.dart';
import 'package:rihla/theme/typography.dart';

class AppearanceSettingsPage extends StatefulWidget {
  const AppearanceSettingsPage({super.key, ProfileService? profileService})
    : _profileService = profileService;

  final ProfileService? _profileService;

  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  late final ProfileService _profileService =
      widget._profileService ?? ProfileService();

  bool _isLoading = true;
  AppThemePreference _themePreference = AppThemePreference.system;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await _profileService.getProfile();
    if (!mounted) return;
    setState(() {
      _themePreference = profile.preferences.themePreference;
      _isLoading = false;
    });
  }

  Future<void> _setThemePreference(AppThemePreference value) async {
    setState(() {
      _themePreference = value;
    });
    final current = await _profileService.getProfile();
    final updated = current.copyWith(
      preferences: current.preferences.copyWith(themePreference: value),
    );
    await _profileService.saveProfile(updated);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final colors = Theme.of(context).colorScheme;
    final palette = RihlaPalette.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Apparence',
          style: AppTypography.title3.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: <Widget>[
          const _SectionHeader(label: 'Thème'),
          const SizedBox(height: AppSpacing.x2),
          _SettingsCard(
            palette: palette,
            children: <Widget>[
              _OptionTile(
                icon: Icons.brightness_auto_outlined,
                label: 'Système',
                selected: _themePreference == AppThemePreference.system,
                onTap: () => _setThemePreference(AppThemePreference.system),
                colors: colors,
              ),
              const SizedBox(height: 6),
              _OptionTile(
                icon: Icons.light_mode_outlined,
                label: 'Clair',
                selected: _themePreference == AppThemePreference.light,
                onTap: () => _setThemePreference(AppThemePreference.light),
                colors: colors,
              ),
              const SizedBox(height: 6),
              _OptionTile(
                icon: Icons.dark_mode_outlined,
                label: 'Sombre',
                selected: _themePreference == AppThemePreference.dark,
                onTap: () => _setThemePreference(AppThemePreference.dark),
                colors: colors,
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
    return Text(
      label,
      style: AppTypography.title3.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.palette, required this.children});

  final RihlaPalette palette;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.divider),
      ),
      child: Column(children: children),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.colors,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: selected ? colors.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: <Widget>[
              Icon(
                icon,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.bodyStrong.copyWith(
                    fontSize: 14.6,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? colors.onPrimaryContainer
                        : colors.onSurface,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? colors.primary : colors.onSurfaceVariant,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
