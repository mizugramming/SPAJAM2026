import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/app/tsunagun_theme.dart';

void main() {
  test('アプリ全体の文字に Kaisei Tokumin を使う', () {
    final theme = tsunagunTheme();
    expect(TsunagunFonts.family, 'KaiseiTokumin');
    for (final style in [
      theme.textTheme.bodyMedium,
      theme.textTheme.titleLarge,
      theme.textTheme.labelLarge,
      theme.primaryTextTheme.bodyMedium,
    ]) {
      expect(style!.fontFamily, TsunagunFonts.family);
    }
  });

  test('部品ごとに文字の形を決めている所も同じフォントにする', () {
    final theme = tsunagunTheme();
    TextStyle? buttonText(ButtonStyle? style) =>
        style!.textStyle!.resolve(<WidgetState>{});
    expect(
      buttonText(theme.filledButtonTheme.style)!.fontFamily,
      TsunagunFonts.family,
    );
    expect(
      buttonText(theme.outlinedButtonTheme.style)!.fontFamily,
      TsunagunFonts.family,
    );
    expect(
      buttonText(theme.textButtonTheme.style)!.fontFamily,
      TsunagunFonts.family,
    );
    expect(
      theme.inputDecorationTheme.labelStyle!.fontFamily,
      TsunagunFonts.family,
    );
    expect(
      theme.inputDecorationTheme.floatingLabelStyle!.fontFamily,
      TsunagunFonts.family,
    );
    expect(
      theme.listTileTheme.titleTextStyle!.fontFamily,
      TsunagunFonts.family,
    );
    expect(
      theme.listTileTheme.subtitleTextStyle!.fontFamily,
      TsunagunFonts.family,
    );
  });

  test('フォント本体とライセンス文を同梱し、フォントとして登録している', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final font = await rootBundle.load('assets/fonts/KaiseiTokumin-Medium.ttf');
    expect(font.lengthInBytes, greaterThan(1000000));

    final manifest = await rootBundle.loadString('FontManifest.json');
    expect(manifest, contains('"family":"KaiseiTokumin"'));
    expect(manifest, contains('assets/fonts/KaiseiTokumin-Medium.ttf'));
    expect(manifest, contains('"weight":500'));
  });
}
