import 'package:flutter/material.dart';
import 'package:rihla/core/theme/rihla_palette.dart';
import 'package:rihla/theme/typography.dart';

class SectionEmpty extends StatelessWidget {
  const SectionEmpty({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final RihlaPalette palette = RihlaPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: palette.cardSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: AppTypography.caption.copyWith(
          fontSize: 13,
          color: palette.textSecondary,
        ),
      ),
    );
  }
}
