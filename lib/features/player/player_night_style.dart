import 'package:flutter/material.dart';

/// Visual styling scoped to the player feature. The app theme is untouched.
abstract final class PlayerNight {
  static const background = Color(0xFF071B28);
  static const surface = Color(0xFF0D2533);
  static const raised = Color(0xFF123444);
  static const lime = Color(0xFFD8F16A);
  static const cyan = Color(0xFF86D5E2);
  static const ink = background;
  static const text = Color(0xFFF0F6F4);
  static const muted = Color(0xFFA8BDC7);
  static const line = Color(0xFF24485B);
  static const error = Color(0xFFFFAC9E);

  static ThemeData themeOf(BuildContext context) {
    final base = Theme.of(context);
    final colors = const ColorScheme.dark(
      primary: lime,
      onPrimary: ink,
      primaryContainer: Color(0xFF263F35),
      onPrimaryContainer: lime,
      secondary: cyan,
      onSecondary: ink,
      secondaryContainer: raised,
      onSecondaryContainer: text,
      surface: surface,
      onSurface: text,
      onSurfaceVariant: muted,
      outline: Color(0xFF477083),
      outlineVariant: line,
      surfaceContainerLowest: background,
      surfaceContainerLow: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: raised,
      surfaceContainerHighest: Color(0xFF1A3D4D),
      error: error,
      onError: ink,
      errorContainer: Color(0xFF412D32),
      onErrorContainer: Color(0xFFFFDAD3),
    );
    final textTheme = base.textTheme.apply(bodyColor: text, displayColor: text);
    const shape = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12)));
    return base.copyWith(
      colorScheme: colors,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: line,
      iconTheme: base.iconTheme.copyWith(color: cyan),
      textTheme: textTheme.copyWith(
        headlineSmall: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.3),
        titleLarge: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        bodyLarge: textTheme.bodyLarge?.copyWith(height: 1.55),
        bodyMedium: textTheme.bodyMedium?.copyWith(height: 1.55),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 56)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
          shape: const WidgetStatePropertyAll(shape),
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? raised : lime,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? muted : ink,
          ),
          textStyle: WidgetStatePropertyAll(
            textTheme.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w800, height: 1.35),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          foregroundColor: cyan,
          disabledForegroundColor: muted,
          side: const BorderSide(color: line),
          shape: shape,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 48),
          foregroundColor: cyan,
          disabledForegroundColor: muted,
          shape: shape,
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: background,
        labelStyle: TextStyle(color: muted),
        floatingLabelStyle: TextStyle(color: cyan),
        helperStyle: TextStyle(color: muted, height: 1.5),
        errorStyle: TextStyle(color: error),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
          borderSide: BorderSide(color: cyan, width: 2),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surface,
        selectedColor: lime,
        secondarySelectedColor: lime,
        checkmarkColor: ink,
        side: const BorderSide(color: line),
        shape: shape,
        labelStyle: textTheme.labelLarge?.copyWith(color: text, fontWeight: FontWeight.w700),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(color: ink, fontWeight: FontWeight.w700),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: lime,
        selectionColor: Color(0x6686D5E2),
        selectionHandleColor: cyan,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: lime),
    );
  }
}
