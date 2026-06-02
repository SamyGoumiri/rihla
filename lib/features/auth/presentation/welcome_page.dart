import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rihla/core/theme/rihla_palette.dart';
import 'package:rihla/features/navigation/presentation/auth_stack.dart';
import 'package:rihla/theme/typography.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key, required this.onContinueAsGuest});

  final FutureOr<void> Function() onContinueAsGuest;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            16 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            children: [
              const _TopBrand(),
              const SizedBox(height: 40),
              Column(
                children: [
                  Text(
                    'Découvrez l\'Algérie',
                    textAlign: TextAlign.center,
                    style: AppTypography.title1.copyWith(
                      color: const Color(0xFFFFFFFF),
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      shadows: const [
                        Shadow(
                          blurRadius: 10,
                          offset: Offset(0, 2),
                          color: Color(0x4D000000),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Lieux authentiques, adresses locales, itinéraires simples.',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: AppTypography.body.copyWith(
                      color: Colors.white.withValues(alpha: 0.62),
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      height: 1.3,
                      shadows: const [
                        Shadow(
                          blurRadius: 8,
                          offset: Offset(0, 2),
                          color: Color(0x40000000),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _MoodIcons(),
                ],
              ),
              const Spacer(),
              _GlassActions(onContinueAsGuest: onContinueAsGuest),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBrand extends StatelessWidget {
  const _TopBrand();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Text(
        'RIHLA',
        style: AppTypography.title2.copyWith(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: 20,
          letterSpacing: 1.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _GlassActions extends StatelessWidget {
  const _GlassActions({required this.onContinueAsGuest});

  final FutureOr<void> Function() onContinueAsGuest;

  @override
  Widget build(BuildContext context) {
    final palette = RihlaPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 0.8,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFAFCF8),
                foregroundColor: palette.brandPrimary,
                minimumSize: const Size.fromHeight(52),
                tapTargetSize: MaterialTapTargetSize.padded,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 4,
                shadowColor: Color(0x3326372D),
              ),
              onPressed: () {
                Navigator.of(context).pushNamed(AuthStack.loginRoute);
              },
              child: Text(
                'Se connecter',
                style: AppTypography.bodyStrong.copyWith(letterSpacing: 0.2),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.36)),
                minimumSize: const Size.fromHeight(52),
                tapTargetSize: MaterialTapTargetSize.padded,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pushNamed(AuthStack.registerRoute);
              },
              child: Text(
                'Créer un compte',
                style: AppTypography.bodyStrong.copyWith(letterSpacing: 0.2),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => onContinueAsGuest(),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withValues(alpha: 0.82),
              minimumSize: const Size(44, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: AppTypography.bodyStrong.copyWith(
                decoration: TextDecoration.underline,
                decorationThickness: 1.1,
                decorationColor: Colors.white.withValues(alpha: 0.35),
              ),
            ),
            child: const Text('Continuer en invité'),
          ),
        ],
      ),
    );
  }
}

class _MoodIcons extends StatelessWidget {
  const _MoodIcons();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _IconBubble(icon: Icons.map_outlined),
        const SizedBox(width: 18),
        _IconBubble(icon: Icons.location_on_outlined),
        const SizedBox(width: 18),
        _IconBubble(icon: Icons.favorite_border),
      ],
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.4));
  }
}
