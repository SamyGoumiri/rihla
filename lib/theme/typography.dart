import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rihla/theme/colors.dart';

class AppTypography {
  const AppTypography._();

  static bool get _useFallbackFonts =>
      Platform.environment.containsKey('FLUTTER_TEST');

  static TextStyle _style({
    required double fontSize,
    required FontWeight fontWeight,
    required double height,
    Color? color,
  }) {
    final TextStyle baseStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      color: color,
    );
    if (_useFallbackFonts) {
      return baseStyle;
    }
    return GoogleFonts.cairo(textStyle: baseStyle);
  }

  static TextStyle get title1 =>
      _style(fontSize: 24, fontWeight: FontWeight.w700, height: 1.25);

  static TextStyle get title2 =>
      _style(fontSize: 20, fontWeight: FontWeight.w700, height: 1.3);

  static TextStyle get title3 =>
      _style(fontSize: 18, fontWeight: FontWeight.w600, height: 1.3);

  static TextStyle get body =>
      _style(fontSize: 16, fontWeight: FontWeight.w400, height: 1.4);

  static TextStyle get bodyStrong =>
      _style(fontSize: 16, fontWeight: FontWeight.w600, height: 1.4);

  static TextStyle get caption =>
      _style(fontSize: 13, fontWeight: FontWeight.w400, height: 1.35);

  static TextStyle get button => _style(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.2,
    color: AppColors.textOnPrimary,
  );
}
