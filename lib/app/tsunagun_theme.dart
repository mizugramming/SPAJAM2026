import 'package:flutter/material.dart';

import 'tsunagun_typography.dart';

/// A small palette shared by the illustrated shell; viewport rules stay in
/// TsunagunApp. Both Medium fonts are bundled and available offline.
abstract final class TsunagunColors {
  static const ink = Color(0xFF392923);
  static const blue = Color(0xFF176DAD);
  static const red = Color(0xFFBB4843);
  static const paper = Color(0xFFFFF7DF);
  static const yellow = Color(0xFFFFD65B);
}

ThemeData tsunagunTheme({
  TsunagunTypeface typeface = TsunagunTypeface.kaiseiTokumin,
}) {
  final family = typeface.fontFamily;
  const ink = TsunagunColors.ink;
  const blue = TsunagunColors.blue;
  const shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(20),
      topRight: Radius.circular(16),
      bottomLeft: Radius.circular(17),
      bottomRight: Radius.circular(21),
    ),
  );
  const line = BorderSide(color: ink, width: 2);
  final scheme = ColorScheme.fromSeed(seedColor: blue, surface: Colors.white)
      .copyWith(
        primary: blue,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFE1F2FF),
        onPrimaryContainer: ink,
        secondary: const Color(0xFF80601C),
        secondaryContainer: TsunagunColors.paper,
        onSecondaryContainer: ink,
        onSurface: ink,
        onSurfaceVariant: const Color(0xFF6B5A50),
        outline: const Color(0xFF85756A),
        outlineVariant: const Color(0xFFE7DED4),
        error: const Color(0xFFAB302D),
        surfaceTint: Colors.transparent,
      );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.white,
    fontFamily: family,
  );
  return base.copyWith(
    textTheme: _mediumTheme(
      base.textTheme,
      family,
    ).apply(bodyColor: ink, displayColor: ink),
    primaryTextTheme: _mediumTheme(base.primaryTextTheme, family),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      border: const UnderlineInputBorder(borderSide: line),
      enabledBorder: const UnderlineInputBorder(borderSide: line),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: blue, width: 3),
      ),
      labelStyle: TextStyle(
        fontFamily: family,
        color: ink,
        fontWeight: FontWeight.w500,
      ),
      floatingLabelStyle: TextStyle(
        fontFamily: family,
        color: blue,
        fontWeight: FontWeight.w500,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        foregroundColor: Colors.white,
        backgroundColor: blue,
        textStyle: TextStyle(
          fontFamily: family,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        shape: shape,
        side: line,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        foregroundColor: ink,
        backgroundColor: TsunagunColors.paper,
        textStyle: TextStyle(
          fontFamily: family,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        shape: shape,
        side: line,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: blue,
        minimumSize: const Size(48, 48),
        textStyle: TextStyle(fontFamily: family, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: shape,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: ink,
      dragHandleSize: Size(40, 4),
      shape: RoundedRectangleBorder(
        side: line,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: blue,
      textColor: ink,
      titleTextStyle: TextStyle(
        fontFamily: family,
        fontSize: 17,
        fontWeight: FontWeight.w500,
        color: ink,
      ),
      subtitleTextStyle: TextStyle(
        fontFamily: family,
        fontWeight: FontWeight.w500,
        fontSize: 14,
        color: Color(0xFF6B5A50),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: blue,
      linearTrackColor: TsunagunColors.paper,
    ),
  );
}

TextTheme _mediumTheme(TextTheme source, String family) {
  TextStyle? medium(TextStyle? style) =>
      style?.copyWith(fontFamily: family, fontWeight: FontWeight.w500);
  return TextTheme(
    displayLarge: medium(source.displayLarge),
    displayMedium: medium(source.displayMedium),
    displaySmall: medium(source.displaySmall),
    headlineLarge: medium(source.headlineLarge),
    headlineMedium: medium(source.headlineMedium),
    headlineSmall: medium(source.headlineSmall),
    titleLarge: medium(source.titleLarge),
    titleMedium: medium(source.titleMedium),
    titleSmall: medium(source.titleSmall),
    bodyLarge: medium(source.bodyLarge),
    bodyMedium: medium(source.bodyMedium),
    bodySmall: medium(source.bodySmall),
    labelLarge: medium(source.labelLarge),
    labelMedium: medium(source.labelMedium),
    labelSmall: medium(source.labelSmall),
  );
}
