import 'package:flutter/material.dart';
import 'package:rihla/core/theme/rihla_palette.dart';

class SettingsIconBox extends StatelessWidget {
  const SettingsIconBox({
    super.key,
    required this.icon,
    this.color,
    this.backgroundColor,
  });

  final IconData icon;
  final Color? color;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final RihlaPalette palette = RihlaPalette.of(context);
    return SizedBox(
      width: 38,
      height: 38,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor ?? palette.brandPrimarySoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: color ?? palette.brandPrimaryOnSoft),
      ),
    );
  }
}
