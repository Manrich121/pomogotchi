import 'package:flutter/material.dart';

class AppTheme {
  static const Color _seedColor = Color(0xFF3A7CA5);
  static const Color _focusColor = Color(0xFF2A9D8F);
  static const Color _breakColor = Color(0xFFE9C46A);
  static const Color _warningColor = Color(0xFFE76F51);

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(seedColor: _seedColor);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      extensions: const [
        PomogotchiThemeTokens(
          focusColor: _focusColor,
          breakColor: _breakColor,
          warningColor: _warningColor,
        ),
      ],
    );
  }
}

@immutable
class PomogotchiThemeTokens extends ThemeExtension<PomogotchiThemeTokens> {
  const PomogotchiThemeTokens({
    required this.focusColor,
    required this.breakColor,
    required this.warningColor,
  });

  final Color focusColor;
  final Color breakColor;
  final Color warningColor;

  @override
  ThemeExtension<PomogotchiThemeTokens> copyWith({
    Color? focusColor,
    Color? breakColor,
    Color? warningColor,
  }) {
    return PomogotchiThemeTokens(
      focusColor: focusColor ?? this.focusColor,
      breakColor: breakColor ?? this.breakColor,
      warningColor: warningColor ?? this.warningColor,
    );
  }

  @override
  ThemeExtension<PomogotchiThemeTokens> lerp(
    covariant ThemeExtension<PomogotchiThemeTokens>? other,
    double t,
  ) {
    if (other is! PomogotchiThemeTokens) {
      return this;
    }

    return PomogotchiThemeTokens(
      focusColor: Color.lerp(focusColor, other.focusColor, t) ?? focusColor,
      breakColor: Color.lerp(breakColor, other.breakColor, t) ?? breakColor,
      warningColor:
          Color.lerp(warningColor, other.warningColor, t) ?? warningColor,
    );
  }
}
