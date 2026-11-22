import 'package:flutter/material.dart';

const bench = Color(0xFF0F0C0C);
const metalPanel = Color(0xFF1C1616);
const seam = Color(0xFF4F2323);
const chalk = Color(0xFFF4F1E8);
const muted = Color(0xFFC9BFBA);

/// 炎の橙。残り時間・時間バー・矢印。
const ember = Color(0xFFFF9A4D);

const shopVermilion = Color(0xFF99482F);
const shopIndigo = Color(0xFF414F59);
const shopPaper = Color(0xFFF6E6C7);
const shopInk = Color(0xFF34261E);

/// アプリの文字（Yuji Syuku）。pubspec.yaml の登録名。
const appFont = 'YujiSyuku';

// 隅を小さく落とした塗り木札。控えめな木目は文字やアイコンの外側に描く。
const _plaqueShape = BeveledRectangleBorder(
  borderRadius: BorderRadius.only(
    topLeft: Radius.circular(5),
    topRight: Radius.circular(3),
    bottomLeft: Radius.circular(3),
    bottomRight: Radius.circular(5),
  ),
);

ButtonStyle shopPlaqueStyle({bool secondary = false}) =>
    FilledButton.styleFrom(
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      foregroundColor: shopPaper,
      backgroundColor: secondary ? shopIndigo : shopVermilion,
      disabledForegroundColor: const Color(0xFFDED1BC),
      disabledBackgroundColor: const Color(0xFF6D6257),
      elevation: 0,
      shape: _plaqueShape,
      textStyle: const TextStyle(
        fontFamily: appFont,
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
      backgroundBuilder: (context, states, child) => CustomPaint(
        painter: _PlaqueEdges(pressed: states.contains(WidgetState.pressed)),
        child: child,
      ),
    ).copyWith(
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return const BorderSide(color: shopPaper, width: 2.5);
        }
        return const BorderSide(color: shopInk, width: 1.8);
      }),
    );

class _PlaqueEdges extends CustomPainter {
  const _PlaqueEdges({required this.pressed});
  final bool pressed;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w < 28 || h < 18) return;
    final paint = Paint()
      ..color = const Color(0x70503225)
      ..strokeWidth = pressed ? 1 : 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(5, h - 3), Offset(w - 6, h - 3), paint);
    if (w < 70) return;
    paint
      ..color = const Color(0x45F3D1A0)
      ..strokeWidth = 1;
    final grain = (w * .13).clamp(8.0, 28.0);
    canvas.drawLine(const Offset(8, 5), Offset(8 + grain, 5.5), paint);
    canvas.drawLine(
      Offset(w - 7 - grain, h - 7),
      Offset(w - 8, h - 7.5),
      paint,
    );
  }

  @override
  bool shouldRepaint(_PlaqueEdges old) => old.pressed != pressed;
}

final workshopTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  fontFamily: appFont,
  fontFamilyFallback: const ['WorkshopSans', 'Noto Sans CJK JP', 'sans-serif'],
  scaffoldBackgroundColor: bench,
  colorScheme: const ColorScheme.dark(
    primary: shopPaper,
    onPrimary: shopInk,
    secondary: shopIndigo,
    onSecondary: shopPaper,
    surface: metalPanel,
    onSurface: chalk,
    onSurfaceVariant: muted,
    outline: seam,
    error: Color(0xFFFFB5A6),
  ),
  filledButtonTheme: FilledButtonThemeData(style: shopPlaqueStyle()),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: shopPlaqueStyle(secondary: true),
  ),
  chipTheme: const ChipThemeData(
    shape: _plaqueShape,
    side: BorderSide(color: shopInk, width: 1.5),
    backgroundColor: shopPaper,
    selectedColor: shopIndigo,
    disabledColor: Color(0xFFB9AC98),
    checkmarkColor: shopPaper,
    labelStyle: TextStyle(
      fontFamily: appFont,
      fontWeight: FontWeight.w700,
      color: shopInk,
    ),
    secondaryLabelStyle: TextStyle(
      fontFamily: appFont,
      fontWeight: FontWeight.w700,
      color: shopPaper,
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: shopPaper,
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
