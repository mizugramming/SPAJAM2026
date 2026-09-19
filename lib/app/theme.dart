import 'package:flutter/material.dart';
import '../core/constants/design_tokens.dart';

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: DesignTokens.accent,
    brightness: Brightness.dark,
    surface: DesignTokens.surface,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: DesignTokens.background,
    fontFamily: 'NotoSansJP',
    fontFamilyFallback: const ['NotoSansJP', 'Roboto'],
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 32,
        height: 1.6,
        letterSpacing: 3,
        fontWeight: FontWeight.w300,
        color: DesignTokens.ink,
      ),
      headlineMedium: TextStyle(
        fontSize: 25,
        height: 1.6,
        letterSpacing: 2,
        fontWeight: FontWeight.w300,
        color: DesignTokens.ink,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        height: 1.5,
        letterSpacing: 1.5,
        color: DesignTokens.ink,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.8, color: DesignTokens.ink),
      bodyMedium: TextStyle(fontSize: 14, height: 1.7, color: DesignTokens.ink),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.7,
        color: DesignTokens.muted,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: DesignTokens.background.withValues(alpha: .96),
      indicatorColor: DesignTokens.accent.withValues(alpha: .16),
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 54),
        textStyle: const TextStyle(
          fontFamily: 'NotoSansJP',
          fontSize: 15,
          letterSpacing: 1,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 50),
        side: const BorderSide(color: DesignTokens.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: DesignTokens.surface.withValues(alpha: .85),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: DesignTokens.border),
      ),
      contentPadding: const EdgeInsets.all(20),
    ),
    dialogTheme: const DialogThemeData(backgroundColor: DesignTokens.surface),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: DesignTokens.surface,
      showDragHandle: true,
    ),
  );
}
