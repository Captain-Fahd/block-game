import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData buildGameTheme() {
  const scheme = ColorScheme.dark(
    surface: GameColors.surface,
    primary: GameColors.accent,
    onPrimary: GameColors.onAccent,
    secondary: GameColors.surfaceRaised,
    onSecondary: GameColors.textPrimary,
    error: GameColors.danger,
    onSurface: GameColors.textPrimary,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: GameColors.background,
    fontFamily: kGameFontFamily,
  );
  return base.copyWith(
    textTheme: base.textTheme
        .apply(
          bodyColor: GameColors.textPrimary,
          displayColor: GameColors.textPrimary,
        )
        .copyWith(
          displayLarge: const TextStyle(
            fontFamily: kGameFontFamily,
            fontSize: 56,
            fontWeight: FontWeight.w900,
            color: GameColors.textPrimary,
          ),
          headlineMedium: const TextStyle(
            fontFamily: kGameFontFamily,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: GameColors.textPrimary,
          ),
          titleMedium: const TextStyle(
            fontFamily: kGameFontFamily,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: GameColors.textPrimary,
          ),
        ),
    dialogTheme: const DialogThemeData(
      backgroundColor: GameColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(GameSpacing.radius)),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? GameColors.onAccent
            : GameColors.textSecondary,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? GameColors.accent
            : GameColors.surfaceRaised,
      ),
    ),
  );
}
