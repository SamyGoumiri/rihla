import 'package:flutter/material.dart';

class RihlaPalette {
  const RihlaPalette({
    required this.scaffoldBackground,
    required this.softSurface,
    required this.cardSurface,
    required this.elevatedSurface,
    required this.divider,
    required this.brandPrimary,
    required this.brandPrimaryContrast,
    required this.brandPrimarySoft,
    required this.brandPrimaryOnSoft,
    required this.brandPrimaryPressed,
    required this.brandPrimaryDisabled,
    required this.textPrimary,
    required this.textSecondary,
    required this.textOnPrimary,
    required this.warningBackground,
    required this.warningBorder,
    required this.warningForeground,
    required this.dangerBackground,
    required this.dangerBorder,
    required this.dangerForeground,
    required this.starColor,
    required this.heroOverlayTop,
    required this.heroOverlayBottom,
  });

  final Color scaffoldBackground;
  final Color softSurface;
  final Color cardSurface;
  final Color elevatedSurface;
  final Color divider;
  final Color brandPrimary;
  final Color brandPrimaryContrast;
  final Color brandPrimarySoft;
  final Color brandPrimaryOnSoft;
  final Color brandPrimaryPressed;
  final Color brandPrimaryDisabled;
  final Color textPrimary;
  final Color textSecondary;
  final Color textOnPrimary;
  final Color warningBackground;
  final Color warningBorder;
  final Color warningForeground;

  final Color dangerBackground;
  final Color dangerBorder;
  final Color dangerForeground;
  final Color starColor;
  final Color heroOverlayTop;
  final Color heroOverlayBottom;

  static const RihlaPalette _light = RihlaPalette(
    scaffoldBackground: Color(0xFFF8F7F3),
    softSurface: Color(0xFFF1F4F1),
    cardSurface: Color(0xFFFFFFFF),
    elevatedSurface: Color(0xFFFFFFFF),
    divider: Color(0xFFE3E8E3),
    brandPrimary: Color(0xFF1F6B4F),
    brandPrimaryContrast: Color(0xFFFFFFFF),
    brandPrimarySoft: Color(0xFFEAF5EE),
    brandPrimaryOnSoft: Color(0xFF1F6B4F),
    brandPrimaryPressed: Color(0xFF14513A),
    brandPrimaryDisabled: Color(0xFF9CC4B1),
    textPrimary: Color(0xFF111A13),
    textSecondary: Color(0xFF5A675E),
    textOnPrimary: Color(0xFFFFFFFF),
    warningBackground: Color(0xFFFFF4E5),
    warningBorder: Color(0xFFF4D4A5),
    warningForeground: Color(0xFF8A5A00),
    dangerBackground: Color(0xFFFBE9E6),
    dangerBorder: Color(0xFFE8B5AE),
    dangerForeground: Color(0xFFB23A2F),
    starColor: Color(0xFFFFB300),
    heroOverlayTop: Color(0x14000000),
    heroOverlayBottom: Color(0x57000000),
  );

  static const RihlaPalette _dark = RihlaPalette(
    scaffoldBackground: Color(0xFF101714),
    softSurface: Color(0xFF1A2520),
    cardSurface: Color(0xFF1F2B25),
    elevatedSurface: Color(0xFF243029),
    divider: Color(0xFF2E3A33),
    brandPrimary: Color(0xFF36B56D),
    brandPrimaryContrast: Color(0xFF06170E),
    brandPrimarySoft: Color(0xFF243F33),
    brandPrimaryOnSoft: Color(0xFFA0E3BB),
    brandPrimaryPressed: Color(0xFF2A8E55),
    brandPrimaryDisabled: Color(0xFF4F7A60),
    textPrimary: Color(0xFFEAF3EE),
    textSecondary: Color(0xFFB7C2BC),
    textOnPrimary: Color(0xFF06170E),
    warningBackground: Color(0xFF3B2C16),
    warningBorder: Color(0xFF7A5A21),
    warningForeground: Color(0xFFE9C68A),
    dangerBackground: Color(0xFF3D1F1B),
    dangerBorder: Color(0xFF7A3D34),
    dangerForeground: Color(0xFFFF7A6B),
    starColor: Color(0xFFE9B941),
    heroOverlayTop: Color(0x33000000),
    heroOverlayBottom: Color(0x9C000000),
  );

  static RihlaPalette of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? _dark : _light;
  }

  static RihlaPalette get light => _light;
  static RihlaPalette get dark => _dark;
}
