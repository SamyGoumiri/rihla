import 'package:flutter/widgets.dart';

class AppSpacing {
  const AppSpacing._();

  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x6 = 24;
  static const double x8 = 32;

  static const EdgeInsets screenPadding = EdgeInsets.all(x4);
  static const EdgeInsets cardPadding = EdgeInsets.all(x4);
  static const EdgeInsets inputContent = EdgeInsets.symmetric(
    horizontal: x3,
    vertical: x3,
  );
}
