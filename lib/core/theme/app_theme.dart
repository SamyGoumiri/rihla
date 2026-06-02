import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rihla/theme/colors.dart';

class AppTheme {
  static ThemeData light() {
    const primaryGreen = AppColors.brandPrimary;
    const secondaryGreen = Color(0xFF4BC77F);
    const lightBackground = Color(0xFFF7F8F6);
    const softSurface = AppColors.surface;
    const onSurfaceDark = Color(0xFF0F2B1A);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryGreen,
      primary: primaryGreen,
      secondary: secondaryGreen,
      error: AppColors.error,
      surface: softSurface,
      brightness: Brightness.light,
    );

    final textTheme = GoogleFonts.cairoTextTheme().copyWith(
      headlineLarge: GoogleFonts.cairo(fontWeight: FontWeight.w700),
      headlineMedium: GoogleFonts.cairo(fontWeight: FontWeight.w700),
      titleLarge: GoogleFonts.cairo(fontWeight: FontWeight.w700),
      titleMedium: GoogleFonts.cairo(fontWeight: FontWeight.w600),
      bodyLarge: GoogleFonts.cairo(height: 1.35),
      bodyMedium: GoogleFonts.cairo(height: 1.35),
      labelLarge: GoogleFonts.cairo(fontWeight: FontWeight.w700),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: lightBackground,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: lightBackground,
        foregroundColor: onSurfaceDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: onSurfaceDark),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      cardTheme: const CardThemeData(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        selectedColor: colorScheme.primaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: const Color(0x1A21A75A),
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.cairo(fontWeight: FontWeight.w700),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: const BorderSide(color: primaryGreen),
          foregroundColor: primaryGreen,
        ),
      ),
    );
  }

  static ThemeData dark() {
    const primaryGreen = Color(0xFF36B56D);
    const secondaryGreen = Color(0xFF4BC77F);
    const darkBackground = Color(0xFF101714);
    const darkSurface = Color(0xFF1A2520);
    const onDarkSurface = Color(0xFFEAF3EE);

    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primaryGreen,
          primary: primaryGreen,
          secondary: secondaryGreen,
          error: const Color(0xFFEF6E6E),
          brightness: Brightness.dark,
        ).copyWith(
          surface: darkSurface,
          onSurface: onDarkSurface,
          onSurfaceVariant: const Color(0xFFB7C2BC),
          surfaceContainerHighest: const Color(0xFF243029),
          outline: const Color(0xFF49544E),
          outlineVariant: const Color(0xFF2E3A33),
          primaryContainer: const Color(0xFF254A37),
          onPrimaryContainer: const Color(0xFFD7F2E2),
        );

    final textTheme =
        GoogleFonts.cairoTextTheme(
          ThemeData(brightness: Brightness.dark).textTheme,
        ).copyWith(
          headlineLarge: GoogleFonts.cairo(
            fontWeight: FontWeight.w700,
            color: onDarkSurface,
          ),
          headlineMedium: GoogleFonts.cairo(
            fontWeight: FontWeight.w700,
            color: onDarkSurface,
          ),
          titleLarge: GoogleFonts.cairo(
            fontWeight: FontWeight.w700,
            color: onDarkSurface,
          ),
          titleMedium: GoogleFonts.cairo(
            fontWeight: FontWeight.w600,
            color: onDarkSurface,
          ),
          bodyLarge: GoogleFonts.cairo(height: 1.35, color: onDarkSurface),
          bodyMedium: GoogleFonts.cairo(height: 1.35, color: onDarkSurface),
          labelLarge: GoogleFonts.cairo(
            fontWeight: FontWeight.w700,
            color: onDarkSurface,
          ),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: darkBackground,
      canvasColor: darkBackground,
      dividerColor: colorScheme.outlineVariant,
      iconTheme: const IconThemeData(color: onDarkSurface),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: darkBackground,
        foregroundColor: onDarkSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: onDarkSurface),
        titleTextStyle: textTheme.titleLarge?.copyWith(color: onDarkSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF202B25),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      cardTheme: CardThemeData(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 0,
        color: darkSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        selectedColor: colorScheme.primaryContainer,
        labelStyle: TextStyle(color: colorScheme.onSurface),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        indicatorColor: const Color(0x4036B56D),
        labelTextStyle: WidgetStatePropertyAll(
          GoogleFonts.cairo(fontWeight: FontWeight.w700, color: onDarkSurface),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide(color: colorScheme.primary),
          foregroundColor: colorScheme.primary,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF243029),
        contentTextStyle: TextStyle(color: onDarkSurface),
        behavior: SnackBarBehavior.floating,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryGreen;
          }
          return colorScheme.onSurfaceVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryGreen.withValues(alpha: 0.5);
          }
          return colorScheme.surfaceContainerHighest;
        }),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurfaceVariant,
        textColor: onDarkSurface,
      ),
    );
  }
}
