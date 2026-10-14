import 'package:flutter/material.dart';

/// Minimal white + orange palette used across the app.
class AppColors {
  // Brand
  static const Color orange = Color(0xFFFF7A1A);
  static const Color orangeDark = Color(0xFFE8630A);
  static const Color orangeSoft = Color(0xFFFFF1E6); // tint for fills/selection

  // Surfaces
  static const Color bg = Color(0xFFFFFFFF); // page background
  static const Color card = Color(0xFFFFFFFF); // card fill
  static const Color cardAlt = Color(0xFFFAF8F6); // subtle grey-white fill
  static const Color track = Color(0xFFF0EDE9); // progress/track background
  static const Color border = Color(0xFFEDE9E4); // hairline borders

  // Text
  static const Color textPrimary = Color(0xFF20242B);
  static const Color textSecondary = Color(0xFF8A8F99);

  /// Shared card decoration: white, hairline border, soft rounded corners.
  static BoxDecoration cardDecoration({double radius = 16}) => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border),
      );
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.orange,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.orange,
    secondary: AppColors.orange,
    surface: AppColors.bg,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
  );
}
