import 'package:flutter/material.dart';

abstract final class AppColors {
  static const ink = Color(0xFF121014);
  static const inkSoft = Color(0xFF29252D);
  static const muted = Color(0xFF716B78);
  static const canvas = Color(0xFFF8F7FA);
  static const surface = Colors.white;
  static const border = Color(0xFFE8E4EC);
  static const borderStrong = Color(0xFFD5CEDD);
  static const brand = Color(0xFF7C3AED);
  static const brandDark = Color(0xFF5B21B6);
  static const brandBright = Color(0xFF9B63F8);
  static const violetMist = Color(0xFFF4EFFF);
  static const violetSoft = Color(0xFFE9DCFF);
  static const aqua = Color(0xFF7C3AED);
  static const success = Color(0xFF12B76A);
  static const warning = Color(0xFFF79009);
  static const danger = Color(0xFFF04438);
}

abstract final class AppTheme {
  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      primary: AppColors.brand,
      secondary: AppColors.aqua,
      surface: AppColors.surface,
      error: AppColors.danger,
      onPrimary: Colors.white,
      onSurface: AppColors.ink,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.canvas,
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displaySmall: const TextStyle(
          color: AppColors.ink,
          fontSize: 34,
          height: 1.08,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
        ),
        headlineSmall: const TextStyle(
          color: AppColors.ink,
          fontSize: 22,
          height: 1.2,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        titleMedium: const TextStyle(
          color: AppColors.ink,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: const TextStyle(
          color: AppColors.ink,
          fontSize: 16,
          height: 1.45,
        ),
        bodyMedium: const TextStyle(
          color: AppColors.muted,
          fontSize: 14,
          height: 1.4,
        ),
        labelLarge: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(22)),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          backgroundColor: AppColors.ink,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFD8D4DC),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: AppColors.brand,
        inactiveTrackColor: AppColors.violetSoft,
        thumbColor: Colors.white,
        overlayColor: AppColors.brand.withValues(alpha: .12),
        trackHeight: 6,
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 11,
          elevation: 2,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? Colors.white
              : const Color(0xFF8E8795);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.brand
              : const Color(0xFFE2DEE6);
        }),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.brandDark),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dividerColor: AppColors.border,
    );
  }
}
