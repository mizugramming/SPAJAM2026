import 'package:flutter/material.dart';

const bench = Color(0xFF0F0C0C);
const metalPanel = Color(0xFF1C1616);
const seam = Color(0xFF4F2323);
const chalk = Color(0xFFF4F1E8);
const muted = Color(0xFFC9BFBA);

/// 炎の橙。残り時間・時間バー・矢印。
const ember = Color(0xFFFF9A4D);

/// 赤の差し色。主ボタン・ロゴのマーク。
const crimson = Color(0xFFC8262E);

/// アプリの文字（Yuji Syuku）。pubspec.yaml の登録名。
const appFont = 'YujiSyuku';

final workshopTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  // 全部の文字を筆の明朝 Yuji Syuku に。入っていない文字はゴシックで表示する。
  fontFamily: appFont,
  fontFamilyFallback: const ['WorkshopSans', 'Noto Sans CJK JP', 'sans-serif'],
  scaffoldBackgroundColor: bench,
  colorScheme: const ColorScheme.dark(
    primary: crimson,
    onPrimary: Colors.white,
    secondary: ember,
    onSecondary: Color(0xFF2A1406),
    surface: metalPanel,
    onSurface: chalk,
    onSurfaceVariant: muted,
    outline: seam,
    error: Color(0xFFFFB5A6),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 54),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(
        fontFamily: appFont,
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
    ),
  ),
  chipTheme: const ChipThemeData(
    shape: RoundedRectangleBorder(
      side: BorderSide.none,
      borderRadius: BorderRadius.all(Radius.circular(2)),
    ),
    side: BorderSide.none,
    backgroundColor: metalPanel,
    selectedColor: crimson,
    checkmarkColor: Colors.white,
    labelStyle: TextStyle(
      fontFamily: appFont,
      fontWeight: FontWeight.w800,
      color: chalk,
    ),
    secondaryLabelStyle: TextStyle(
      fontFamily: appFont,
      fontWeight: FontWeight.w800,
      color: Colors.white,
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      minimumSize: const Size(48, 48),
      textStyle: const TextStyle(
        fontFamily: appFont,
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    ),
  ),
);

class PrimaryAction extends StatelessWidget {
  const PrimaryAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
      label: Text(label),
    ),
  );
}
