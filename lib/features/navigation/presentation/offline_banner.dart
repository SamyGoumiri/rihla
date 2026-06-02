import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rihla/core/services/connectivity_service.dart';
import 'package:rihla/core/theme/rihla_palette.dart';
import 'package:rihla/data/repositories/site_repository.dart';
import 'package:rihla/theme/typography.dart';

class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key, ConnectivityService? connectivityService})
    : _connectivityService = connectivityService;

  final ConnectivityService? _connectivityService;

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  late final ConnectivityService _connectivity =
      widget._connectivityService ?? ConnectivityService();

  StreamSubscription<bool>? _subscription;
  bool _isOnline = true;
  bool _isReloading = false;

  @override
  void initState() {
    super.initState();
    _subscription = _connectivity.isOnlineStream.listen((online) {
      if (!mounted) return;
      setState(() {
        _isOnline = online;
      });
    });

    _connectivity.isOnlineNow().then((online) {
      if (!mounted) return;
      setState(() {
        _isOnline = online;
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    if (_isReloading) return;
    setState(() => _isReloading = true);
    try {
      await SiteRepository.instance.getSites(forceRefresh: true);
      final online = await _connectivity.isOnlineNow();
      if (!mounted) return;
      setState(() {
        _isOnline = online;
      });
    } finally {
      if (mounted) {
        setState(() => _isReloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = RihlaPalette.of(context);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return SizeTransition(
          sizeFactor: animation,

          // ignore: deprecated_member_use
          axisAlignment: -1,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: _isOnline
          ? const SizedBox.shrink(key: ValueKey('online'))
          : Container(
              key: const ValueKey('offline'),
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              color: palette.warningBackground,
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.wifi_off_rounded,
                      color: palette.warningForeground,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Hors ligne — affichage des données en cache',
                        style: AppTypography.caption.copyWith(
                          fontSize: 12.6,
                          fontWeight: FontWeight.w600,
                          color: palette.warningForeground,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _isReloading ? null : _reload,
                      style: TextButton.styleFrom(
                        foregroundColor: palette.warningForeground,
                        textStyle: AppTypography.caption.copyWith(
                          fontSize: 12.6,
                          fontWeight: FontWeight.w700,
                        ),
                        minimumSize: const Size(64, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: _isReloading
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  palette.warningForeground,
                                ),
                              ),
                            )
                          : const Text('Recharger'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
