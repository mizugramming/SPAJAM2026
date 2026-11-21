import 'package:flutter/material.dart';

const bench = Color(0xFF121717);
const metalPanel = Color(0xFF202626);
const seam = Color(0xFF404844);
const chalk = Color(0xFFF4F1E8);
const muted = Color(0xFFC1C8BE);
const ember = Color(0xFFECC198);

final workshopTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  fontFamily: 'WorkshopSans',
  fontFamilyFallback: const ['Noto Sans CJK JP', 'sans-serif'],
  scaffoldBackgroundColor: bench,
  colorScheme: const ColorScheme.dark(
    primary: ember,
    onPrimary: Color(0xFF291B10),
    secondary: Color(0xFFA6C4B6),
    onSecondary: Color(0xFF14251E),
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
        fontFamily: 'WorkshopSans',
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      minimumSize: const Size(48, 48),
      textStyle: const TextStyle(
        fontFamily: 'WorkshopSans',
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
