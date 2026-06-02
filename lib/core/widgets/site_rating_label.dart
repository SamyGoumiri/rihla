import 'package:flutter/material.dart';
import 'package:rihla/core/theme/rihla_palette.dart';
import 'package:rihla/theme/typography.dart';

class SiteRatingLabel extends StatelessWidget {
  const SiteRatingLabel({
    super.key,
    required this.rating,
    this.onDark = false,
    this.fontSize = 12.2,
  });

  final double? rating;

  final bool onDark;

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final double? value = rating;
    if (value == null || value <= 0) {
      return const SizedBox.shrink();
    }
    final RihlaPalette palette = RihlaPalette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.star_rounded, size: fontSize + 3, color: palette.starColor),
        const SizedBox(width: 2),
        Text(
          value.toStringAsFixed(1),
          style: AppTypography.caption.copyWith(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: onDark ? Colors.white : palette.textPrimary,
          ),
        ),
      ],
    );
  }
}
