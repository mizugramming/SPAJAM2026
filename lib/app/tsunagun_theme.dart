import 'package:flutter/material.dart';

/// A small palette shared by the illustrated shell; viewport rules stay in
/// TsunagunApp. No font or package download is required to render the UI.
abstract final class TsunagunColors {
  static const ink = Color(0xFF392923);
  static const blue = Color(0xFF176DAD);
  static const red = Color(0xFFBB4843);
  static const paper = Color(0xFFFFF7DF);
  static const yellow = Color(0xFFFFD65B);
}

ThemeData tsunagunTheme() {
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
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: ink, displayColor: ink),
    inputDecorationTheme: const InputDecorationTheme(
      filled: false,
      border: UnderlineInputBorder(borderSide: line),
      enabledBorder: UnderlineInputBorder(borderSide: line),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: blue, width: 3),
      ),
      labelStyle: TextStyle(color: ink, fontWeight: FontWeight.w700),
      floatingLabelStyle: TextStyle(color: blue, fontWeight: FontWeight.w800),
      contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        foregroundColor: Colors.white,
        backgroundColor: blue,
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
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
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        shape: shape,
        side: line,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: blue,
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
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
    listTileTheme: const ListTileThemeData(
      iconColor: blue,
      textColor: ink,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: ink,
      ),
      subtitleTextStyle: TextStyle(fontSize: 14, color: Color(0xFF6B5A50)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: blue,
      linearTrackColor: TsunagunColors.paper,
    ),
  );
}
