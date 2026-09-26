import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/app/tsunagun_theme.dart';
import 'package:spajam2026/app/tsunagun_typography.dart';
import 'package:spajam2026/domain/models.dart';
import 'package:spajam2026/features/demo/final_awards.dart';

RankEntry _entry(
  String name, {
  required int rank,
  int power = 3,
  bool isSelf = false,
}) => RankEntry(
  participant: Participant(
    id: name,
    profile: Profile(nickname: name, hobby: '', comment: ''),
    team: isSelf ? Team.red : Team.blue,
    isSelf: isSelf,
  ),
  normalCount: power ~/ 3,
  boneCount: power % 3,
  power: power,
  rank: rank,
);

FinalSnapshot _snapshot(
  List<RankEntry> entries, {
  List<String> mvps = const [],
}) => FinalSnapshot(
  redPower: entries
      .where((entry) => entry.participant.team == Team.red)
      .fold(0, (total, entry) => total + entry.power),
  bluePower: entries
      .where((entry) => entry.participant.team == Team.blue)
      .fold(0, (total, entry) => total + entry.power),
  rankings: entries,
  mvpIds: mvps,
);

Widget _scene(
  FinalSnapshot snapshot, {
  double scale = 1,
  TsunagunTypeface typeface = TsunagunTypeface.kaiseiTokumin,
}) => MaterialApp(
  theme: tsunagunTheme(typeface: typeface),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
    child: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: FinalAwards(snapshot: snapshot),
      ),
    ),
  ),
);

Finder _row(String name) => find.byKey(ValueKey('ranking-$name'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Exercise Japanese wrapping and multi-digit ranks with both shipped fonts.
    for (final entry in {
      'KaiseiTokumin': 'assets/fonts/KaiseiTokumin-Medium.ttf',
      'MPlusRounded1c': 'assets/fonts/MPLUSRounded1c-Medium.ttf',
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(rootBundle.load(entry.value));
      await loader.load();
    }
  });

  testWidgets('3位までを表示し、上位の自分を重複させずMVPも維持する', (tester) async {
    final result = _snapshot(
      [
        _entry('トップ', rank: 1, power: 15),
        _entry('わたし', rank: 2, power: 12, isSelf: true),
        _entry('三位さん', rank: 3, power: 9),
        _entry('四位さん', rank: 4, power: 6),
        _entry('五位さん', rank: 5),
      ],
      mvps: ['トップ'],
    );
    await tester.pumpWidget(_scene(result));
    await tester.pumpAndSettle();

    for (final name in ['トップ', 'わたし', '三位さん']) {
      expect(_row(name), findsOneWidget);
    }
    expect(find.text('わたし（あなた）'), findsOneWidget);
    expect(find.text('四位さん'), findsNothing);
    expect(find.text('五位さん'), findsNothing);
    expect(find.text('あなたの順位'), findsNothing);
    expect(find.text('今日のMVP'), findsOneWidget);
    expect(find.text('トップ'), findsNWidgets(2));
    expect(find.text('ちから 15'), findsNWidgets(2));
    expect(find.text('今回は該当者なし'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('4位以下の自分を上位一覧の下に得点内訳とともに表示する', (tester) async {
    await tester.pumpWidget(
      _scene(
        _snapshot(
          [
            _entry('一位さん', rank: 1, power: 20),
            _entry('二位さん', rank: 2, power: 17),
            _entry('三位さん', rank: 3, power: 14),
            _entry('わたし', rank: 4, power: 11, isSelf: true),
            _entry('五位さん', rank: 5, power: 8),
          ],
          mvps: ['一位さん'],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('あなたの順位'), findsOneWidget);
    expect(_row('わたし'), findsOneWidget);
    expect(find.text('わたし（あなた）'), findsOneWidget);
    expect(find.text('五位さん'), findsNothing);
    expect(
      tester.getTopLeft(find.text('あなたの順位')).dy,
      greaterThan(tester.getBottomLeft(_row('三位さん')).dy),
    );
    expect(
      tester.getTopLeft(_row('わたし')).dy,
      greaterThan(tester.getBottomLeft(find.text('あなたの順位')).dy),
    );
    for (final text in [
      '4',
      '赤チーム',
      '子分 3匹 × 3pt = 9pt',
      '骨 2匹 × 1pt = 2pt',
      'ちから 11',
    ]) {
      expect(
        find.descendant(of: _row('わたし'), matching: find.text(text)),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('同率3位を人数で切らず全員表示し、snapshotの順序と順位を使う', (tester) async {
    await tester.pumpWidget(
      _scene(
        _snapshot(
          [
            _entry('先頭', rank: 1, power: 15),
            _entry('二番', rank: 2, power: 12),
            _entry('同率の仲間', rank: 3, power: 9),
            _entry('同率の自分', rank: 3, power: 9, isSelf: true),
            _entry('五番', rank: 5, power: 6),
          ],
          mvps: ['先頭'],
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final name in ['先頭', '二番', '同率の仲間', '同率の自分']) {
      expect(_row(name), findsOneWidget);
    }
    expect(find.text('3'), findsNWidgets(2));
    expect(find.text('同率の自分（あなた）'), findsOneWidget);
    expect(find.text('五番'), findsNothing);
    expect(find.text('あなたの順位'), findsNothing);
    expect(
      tester.getTopLeft(_row('同率の仲間')).dy,
      lessThan(tester.getTopLeft(_row('同率の自分')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('全員0点同率1位では全員とMVPなしを表示し、空の順位も扱える', (tester) async {
    for (final count in [6, 0]) {
      await tester.pumpWidget(
        _scene(
          _snapshot([
            for (var i = 0; i < count; i++)
              _entry('仲間$i', rank: 1, power: 0, isSelf: i == 5),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('今回は該当者なし'), findsOneWidget);
      expect(find.text('あなたの順位'), findsNothing);
      expect(find.text('1'), findsNWidgets(count));
      for (var i = 0; i < count; i++) {
        expect(_row('仲間$i'), findsOneWidget);
      }
      if (count == 0) {
        expect(find.text('仲間5（あなた）'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('幅320・文字2倍・4桁順位でも両フォントで全文を表示してスクロールできる', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    const name = 'つながる仲間と一緒に歩くプロフィール';
    final result = _snapshot(
      [
        _entry('トップ', rank: 1, power: 999),
        _entry(name, rank: 1234, power: 302, isSelf: true),
      ],
      mvps: ['トップ'],
    );

    for (final typeface in TsunagunTypeface.values) {
      await tester.pumpWidget(_scene(result, scale: 2, typeface: typeface));
      await tester.pumpAndSettle();
      expect(find.text('$name（あなた）'), findsOneWidget);
      expect(find.text('子分 100匹 × 3pt = 300pt'), findsOneWidget);
      expect(find.text('骨 2匹 × 1pt = 2pt'), findsOneWidget);
      final paragraphs = tester.renderObjectList<RenderParagraph>(
        find.descendant(of: _row(name), matching: find.byType(RichText)),
      );
      for (final paragraph in paragraphs) {
        final origin = paragraph.localToGlobal(Offset.zero);
        expect(origin.dx, greaterThanOrEqualTo(20));
        expect(origin.dx + paragraph.size.width, lessThanOrEqualTo(300.01));
        expect(paragraph.didExceedMaxLines, isFalse);
      }
      final rank = tester.renderObject<RenderParagraph>(
        find.descendant(of: find.text('1234'), matching: find.byType(RichText)),
      );
      expect(
        rank.getBoxesForSelection(
          const TextSelection(baseOffset: 0, extentOffset: 4),
        ),
        hasLength(1),
      );
      await tester.ensureVisible(find.text('ちから 302'));
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('ちから 302')).bottom,
        lessThanOrEqualTo(640),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
