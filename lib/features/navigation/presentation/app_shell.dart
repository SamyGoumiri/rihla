import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rihla/core/theme/rihla_palette.dart';
import 'package:rihla/features/discover/presentation/discover_page.dart';
import 'package:rihla/features/map/presentation/map_page.dart';
import 'package:rihla/features/navigation/presentation/offline_banner.dart';
import 'package:rihla/features/settings/presentation/settings_page.dart';
import 'package:rihla/theme/typography.dart';

typedef AppShellPagesBuilder =
    List<Widget> Function({
      required bool isGuestMode,
      Future<void> Function()? onSignOut,
      Future<void> Function()? onManualSync,
      Future<void> Function()? onExitSession,
    });

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.isGuestMode,
    this.onSignOut,
    this.onManualSync,
    this.onExitSession,
    this.pagesBuilder,
  });

  final bool isGuestMode;
  final Future<void> Function()? onSignOut;
  final Future<void> Function()? onManualSync;
  final Future<void> Function()? onExitSession;
  final AppShellPagesBuilder? pagesBuilder;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  final List<int> _tabHistory = <int>[];

  void _selectTab(int index, {bool addToHistory = true}) {
    if (_selectedIndex == index) {
      return;
    }

    if (addToHistory) {
      _tabHistory.add(_selectedIndex);
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  void _handleBackNavigation() {
    if (_tabHistory.isNotEmpty) {
      final previousIndex = _tabHistory.removeLast();
      setState(() {
        _selectedIndex = previousIndex;
      });
      return;
    }

    if (_selectedIndex != 0) {
      setState(() {
        _selectedIndex = 0;
      });
      return;
    }

    SystemNavigator.pop();
  }

  List<Widget> _buildPages() {
    final customPagesBuilder = widget.pagesBuilder;
    if (customPagesBuilder != null) {
      return customPagesBuilder(
        isGuestMode: widget.isGuestMode,
        onSignOut: widget.onSignOut,
        onManualSync: widget.onManualSync,
        onExitSession: widget.onExitSession,
      );
    }

    return <Widget>[
      DiscoverPage(isGuestMode: widget.isGuestMode),
      const MapPage(),
      SettingsPage(
        isGuestMode: widget.isGuestMode,
        onExitSession: () {
          if (widget.isGuestMode) {
            widget.onExitSession?.call();
          } else {
            widget.onSignOut?.call();
          }
        },
      ),
    ];
  }

  void _onDestinationTap(int index) {
    _selectTab(index);
  }

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: RihlaPalette.of(context).scaffoldBackground,
        body: Column(
          children: <Widget>[
            const OfflineBanner(),
            Expanded(
              child: IndexedStack(index: _selectedIndex, children: pages),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: _FloatingNavBar(
            selectedIndex: _selectedIndex,
            onTap: _onDestinationTap,
          ),
        ),
      ),
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({required this.selectedIndex, required this.onTap});

  final int selectedIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    _NavItem('Explorer', Icons.explore_outlined, Icons.explore),
    _NavItem('Carte', Icons.map_outlined, Icons.map),
    _NavItem('Profil', Icons.person_outline_rounded, Icons.person_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final RihlaPalette palette = RihlaPalette.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: palette.cardSurface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: List.generate(_items.length, (index) {
          final item = _items[index];
          final isActive = index == selectedIndex;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => onTap(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: isActive
                          ? colors.primary.withValues(alpha: 0.16)
                          : Colors.transparent,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isActive ? item.activeIcon : item.icon,
                          color: isActive
                              ? colors.primary
                              : palette.textSecondary,
                          size: 21,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: AppTypography.caption.copyWith(
                            fontSize: 11,
                            color: isActive
                                ? colors.primary
                                : palette.textSecondary,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _NavItem {
  const _NavItem(this.label, this.icon, this.activeIcon);

  final String label;
  final IconData icon;
  final IconData activeIcon;
}
