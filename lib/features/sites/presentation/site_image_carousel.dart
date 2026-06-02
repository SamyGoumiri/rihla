import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rihla/core/widgets/app_site_image.dart';

class SiteImageCarousel extends StatefulWidget {
  const SiteImageCarousel({
    super.key,
    required this.imageUrls,
    this.holdDuration = const Duration(seconds: 4),
    this.transitionDuration = const Duration(milliseconds: 600),
    this.manualResumeDelay = const Duration(seconds: 6),
    this.fit = BoxFit.cover,
    this.fallback,
  });

  final List<String> imageUrls;
  final Duration holdDuration;
  final Duration transitionDuration;
  final Duration manualResumeDelay;
  final BoxFit fit;
  final Widget? fallback;

  @override
  State<SiteImageCarousel> createState() => _SiteImageCarouselState();
}

class _SiteImageCarouselState extends State<SiteImageCarousel> {
  int _index = 0;
  Timer? _autoTimer;
  Timer? _resumeTimer;
  bool _autoPaused = false;

  @override
  void initState() {
    super.initState();
    _startAuto();
  }

  @override
  void didUpdateWidget(covariant SiteImageCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrls.length != widget.imageUrls.length ||
        oldWidget.holdDuration != widget.holdDuration) {
      _autoTimer?.cancel();
      _resumeTimer?.cancel();
      _autoPaused = false;
      if (_index >= widget.imageUrls.length) {
        _index = 0;
      }
      _startAuto();
    }
  }

  void _startAuto() {
    if (widget.imageUrls.length <= 1) return;
    _autoTimer = Timer.periodic(widget.holdDuration, (_) {
      if (!mounted || _autoPaused) return;
      setState(() {
        _index = (_index + 1) % widget.imageUrls.length;
      });
    });
  }

  void _onUserInteract() {
    _autoPaused = true;
    _resumeTimer?.cancel();
    _resumeTimer = Timer(widget.manualResumeDelay, () {
      if (!mounted) return;
      setState(() {
        _autoPaused = false;
      });
    });
  }

  void _goPrevious() {
    if (widget.imageUrls.length <= 1) return;
    _onUserInteract();
    setState(() {
      _index = (_index - 1 + widget.imageUrls.length) % widget.imageUrls.length;
    });
  }

  void _goNext() {
    if (widget.imageUrls.length <= 1) return;
    _onUserInteract();
    setState(() {
      _index = (_index + 1) % widget.imageUrls.length;
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _resumeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return widget.fallback ?? const SizedBox.shrink();
    }
    final hasMultiple = widget.imageUrls.length > 1;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        AnimatedSwitcher(
          duration: widget.transitionDuration,
          transitionBuilder: (Widget child, Animation<double> animation) =>
              FadeTransition(opacity: animation, child: child),
          child: KeyedSubtree(
            key: ValueKey<int>(_index),
            child: AppSiteImage(
              imagePath: widget.imageUrls[_index],
              fit: widget.fit,
              fallback: widget.fallback,
            ),
          ),
        ),
        if (hasMultiple) ...<Widget>[
          Positioned.fill(
            child: IgnorePointer(
              ignoring: true,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: <Color>[
                      Colors.black.withValues(alpha: 0.12),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.12),
                    ],
                    stops: const <double>[0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _CarouselNavButton(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Image précédente',
                onTap: _goPrevious,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _CarouselNavButton(
                icon: Icons.chevron_right_rounded,
                tooltip: 'Image suivante',
                onTap: _goNext,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Center(
              child: _CarouselDots(
                count: widget.imageUrls.length,
                activeIndex: _index,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _CarouselNavButton extends StatelessWidget {
  const _CarouselNavButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.42),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.45),
                width: 1,
              ),
            ),
            child: Icon(icon, size: 26, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _CarouselDots extends StatelessWidget {
  const _CarouselDots({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List<Widget>.generate(count, (int i) {
          final bool active = i == activeIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: active ? 16 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: active
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }),
      ),
    );
  }
}
