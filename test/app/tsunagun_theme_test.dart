import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/app/tsunagun_theme.dart';
import 'package:spajam2026/app/tsunagun_typography.dart';

Iterable<TextStyle?> _styles(TextTheme theme) => [
  theme.displayLarge,
  theme.displayMedium,
  theme.displaySmall,
  theme.headlineLarge,
  theme.headlineMedium,
  theme.headlineSmall,
  theme.titleLarge,
  theme.titleMedium,
  theme.titleSmall,
  theme.bodyLarge,
  theme.bodyMedium,
  theme.bodySmall,
  theme.labelLarge,
  theme.labelMedium,
  theme.labelSmall,
];

void main() {
  test('既定はKaisei Tokuminで、全体の文字には選択した字体の500を使う', () {
    expect(TsunagunFonts.family, 'KaiseiTokumin');
    expect(TsunagunTypeface.kaiseiTokumin.fontFamily, TsunagunFonts.family);
    expect(
      tsunagunTheme().textTheme.bodyMedium!.fontFamily,
      TsunagunFonts.family,
    );
    for (final typeface in TsunagunTypeface.values) {
      final theme = tsunagunTheme(typeface: typeface);
      for (final style in [
        ..._styles(theme.textTheme),
        ..._styles(theme.primaryTextTheme),
      ]) {
        expect(style!.fontFamily, typeface.fontFamily);
        expect(style.fontWeight, FontWeight.w500);
      }
    }
  });

  test('ボタン・入力ラベル・リストにも選択した字体の500を適用する', () {
    TextStyle? buttonText(ButtonStyle? style) =>
        style!.textStyle!.resolve(<WidgetState>{});
    for (final typeface in TsunagunTypeface.values) {
      final theme = tsunagunTheme(typeface: typeface);
      for (final style in [
        buttonText(theme.filledButtonTheme.style),
        buttonText(theme.outlinedButtonTheme.style),
        buttonText(theme.textButtonTheme.style),
        theme.inputDecorationTheme.labelStyle,
        theme.inputDecorationTheme.floatingLabelStyle,
        theme.listTileTheme.titleTextStyle,
        theme.listTileTheme.subtitleTextStyle,
      ]) {
        expect(style!.fontFamily, typeface.fontFamily);
        expect(style.fontWeight, FontWeight.w500);
      }
    }
  });

  test('両フォント本体とライセンス文を同梱し、500として登録している', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final manifest =
        (jsonDecode(await rootBundle.loadString('FontManifest.json')) as List)
            .cast<Map<String, dynamic>>();
    for (final font in [
      (
        family: 'KaiseiTokumin',
        asset: 'assets/fonts/KaiseiTokumin-Medium.ttf',
        license: 'assets/fonts/OFL-KaiseiTokumin.txt',
      ),
      (
        family: 'MPlusRounded1c',
        asset: 'assets/fonts/MPLUSRounded1c-Medium.ttf',
        license: 'assets/fonts/OFL-MPlusRounded1c.txt',
      ),
    ]) {
      expect(
        (await rootBundle.load(font.asset)).lengthInBytes,
        greaterThan(1000000),
      );
      final registered = manifest.singleWhere(
        (entry) => entry['family'] == font.family,
      );
      expect(
        registered['fonts'],
        contains(equals({'asset': font.asset, 'weight': 500})),
      );
      final license = await rootBundle.loadString(font.license);
      expect(license, contains('SIL OPEN FONT LICENSE Version 1.1'));
      expect(license, contains('Copyright'));
    }
  });
}
