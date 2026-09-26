import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/app/tsunagun_app.dart';
import 'package:spajam2026/app/tsunagun_theme.dart';
import 'package:spajam2026/app/tsunagun_typography.dart';
import 'package:spajam2026/data/demo_controller.dart';
import 'package:spajam2026/domain/models.dart';
import 'package:spajam2026/features/demo/can_stage.dart';
import 'package:spajam2026/features/demo/curved_label.dart';

const _longProfile = Profile(
  nickname: 'つながる仲間と一緒に歩くプロフィール',
  hobby: '喫茶店めぐりと写真撮影。知らない街の景色を見つけて友達とおしゃべりすることが好きです。',
  comment: 'はじめまして！今日は皆さんと力を合わせて遊びたいです。おすすめの場所や好きなことを聞かせてください。',
);

void _phone(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 740);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

RenderParagraph _paragraph(WidgetTester tester, Finder text) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(of: text, matching: find.byType(RichText)).first,
    );

void _expectTypeface(
  WidgetTester tester,
  Finder text,
  TsunagunTypeface typeface, {
  FontWeight weight = FontWeight.w500,
}) {
  final paragraph = _paragraph(tester, text);
  expect(paragraph.text.style!.fontFamily, typeface.fontFamily);
  expect(paragraph.text.style!.fontWeight, weight);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _key(WidgetTester tester, String name) =>
    _tap(tester, find.byKey(Key(name)));

Future<void> _chooseFont(WidgetTester tester, String name) async {
  await _key(tester, 'demo-info');
  await _key(tester, name);
  if (find.byType(BottomSheet).evaluate().isNotEmpty) {
    await _tap(tester, find.text('閉じる').last);
  }
}

Widget _can(TsunagunTypeface typeface, {bool bold = false}) => MaterialApp(
  theme: tsunagunTheme(typeface: typeface),
  home: MediaQuery(
    data: MediaQueryData(
      textScaler: const TextScaler.linear(2),
      boldText: bold,
    ),
    child: const Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: CanStage(
          phase: AppPhase.profile,
          profile: _longProfile,
          team: Team.red,
        ),
      ),
    ),
  ),
);

void _expectLabelBounds(WidgetTester tester) {
  final can = tester.getRect(find.byType(TunaCan));
  final label = tester.getRect(find.byType(CurvedLabel));
  expect(can.inflate(.1).contains(label.topLeft), isTrue);
  expect(can.inflate(.1).contains(label.bottomRight), isTrue);
  expect(can.left, greaterThanOrEqualTo(0));
  expect(can.right, lessThanOrEqualTo(360));
  for (final value in [
    _longProfile.nickname,
    _longProfile.hobby,
    _longProfile.comment,
  ]) {
    final finder = find.text(value);
    final rect = tester.getRect(finder);
    expect(label.inflate(.1).contains(rect.topLeft), isTrue);
    expect(label.inflate(.1).contains(rect.bottomRight), isTrue);
    expect(_paragraph(tester, finder).didExceedMaxLines, isFalse);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Widget tests otherwise substitute Ahem: load the shipped fonts so glyph
    // widths, Japanese line breaks and can height use their actual metrics.
    for (final entry in {
      'KaiseiTokumin': 'assets/fonts/KaiseiTokumin-Medium.ttf',
      'MPlusRounded1c': 'assets/fonts/MPLUSRounded1c-Medium.ttf',
    }.entries) {
      final loader = FontLoader(entry.key)
        ..addFont(rootBundle.load(entry.value));
      await loader.load();
    }
  });

  for (final typeface in TsunagunTypeface.values) {
    testWidgets('${typeface.name}: 実フォント・長文・文字2倍でも曲面ラベルを缶の内側に収める', (
      tester,
    ) async {
      _phone(tester);
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(_can(typeface));
        await tester.pumpAndSettle();
        _expectLabelBounds(tester);
        for (final value in [
          _longProfile.nickname,
          _longProfile.hobby,
          _longProfile.comment,
        ]) {
          await tester.ensureVisible(find.text(value));
          await tester.pumpAndSettle();
          _expectTypeface(tester, find.text(value), typeface);
          // The can merges its printed fields into one accessibility node.
          // Check the spoken text, not a standalone node for each Text widget.
          final spokenNodes = find.semantics
              .byLabel(RegExp(RegExp.escape(value)))
              .evaluate();
          expect(spokenNodes, hasLength(1));
          final spokenLabel = spokenNodes.single.label;
          expect(
            spokenLabel,
            endsWith(
              [
                'ニックネーム：',
                _longProfile.nickname,
                '趣味：',
                _longProfile.hobby,
                'ひとこと：',
                _longProfile.comment,
              ].join('\n'),
            ),
          );
          expect(value.allMatches(spokenLabel), hasLength(1));
        }
        // A long last line remains reachable by scrolling rather than shrinking.
        await tester.ensureVisible(find.text(_longProfile.comment));
        expect(
          tester.getRect(find.text(_longProfile.comment)).top,
          lessThan(740),
        );
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }

  testWidgets('DEMOメニューでフォントを切り替えても入力・報酬・チーム・最後の開始待ちを保持する', (tester) async {
    _phone(tester);
    final demo = DemoController(autoTick: false);
    addTearDown(demo.dispose);
    await tester.pumpWidget(
      TsunagunApp(animateCharacters: false, controller: demo),
    );
    await tester.pumpAndSettle();
    _expectTypeface(tester, find.text('はだ缶'), TsunagunTypeface.kaiseiTokumin);
    await _key(tester, 'create-room');
    final inputs = {
      'nickname': 'つな工場の仲間',
      'hobby': '写真と喫茶店めぐり',
      'comment': 'いっしょに遊ぼう！',
    };
    for (final entry in inputs.entries) {
      final field = find.byKey(Key(entry.key));
      await tester.ensureVisible(field);
      await tester.enterText(field, entry.value);
      await tester.pumpAndSettle();
    }
    await _chooseFont(tester, 'font-rounded');
    expect(demo.phase, AppPhase.profile);
    expect(demo.profileDraft.nickname, inputs['nickname']);
    expect(demo.profileDraft.hobby, inputs['hobby']);
    expect(demo.profileDraft.comment, inputs['comment']);
    for (final entry in inputs.entries) {
      expect(
        tester.widget<TextField>(find.byKey(Key(entry.key))).controller!.text,
        entry.value,
      );
    }
    _expectTypeface(
      tester,
      find.byKey(const Key('can-nickname')),
      TsunagunTypeface.mPlusRounded,
    );
    await _key(tester, 'save-profile');
    await _key(tester, 'start-event');
    final team = demo.self.team;
    final peer = demo.peers.firstWhere((person) => person.team != team);
    demo.openPairing();
    demo.selectPeer(peer.id);
    demo.confirmPeer();
    demo.injectOutcome(Outcome.loss);
    await tester.pumpAndSettle();
    final reward = demo.lastResult;
    final follower = demo.followers.single;
    final remaining = demo.remaining;
    await _chooseFont(tester, 'font-kaisei');
    expect(demo.phase, AppPhase.result);
    expect(demo.self.team, team);
    expect(demo.self.profile.nickname, inputs['nickname']);
    expect(demo.lastResult, same(reward));
    expect(demo.followers.single, same(follower));
    expect(demo.boneCount, 1);
    expect(demo.power, 1);
    expect(demo.remaining, remaining);
    _expectTypeface(
      tester,
      find.text('ショBONE'),
      TsunagunTypeface.kaiseiTokumin,
    );
    await _key(tester, 'return-home');
    expect(demo.phase, AppPhase.home);
    demo.advance(demo.remaining);
    await tester.pumpAndSettle();
    final finalSnapshot = demo.finalSnapshot;
    await _chooseFont(tester, 'font-rounded');
    expect(demo.phase, AppPhase.finale);
    expect(demo.finalSnapshot, same(finalSnapshot));
    expect(find.byKey(const Key('start-tug-button')), findsOneWidget);
    expect(find.byKey(const Key('tug-red-power')), findsNothing);
    _expectTypeface(
      tester,
      find.text('最後の大綱引き'),
      TsunagunTypeface.mPlusRounded,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('初期書体の指定をThemeと入口・結果の実描画へ適用し、500で揃える', (tester) async {
    _phone(tester);
    for (final typeface in TsunagunTypeface.values) {
      final demo = DemoController(autoTick: false);
      addTearDown(demo.dispose);
      await tester.pumpWidget(
        TsunagunApp(
          animateCharacters: false,
          key: ValueKey(typeface),
          controller: demo,
          initialTypeface: typeface,
        ),
      );
      await tester.pumpAndSettle();
      final theme = Theme.of(tester.element(find.text('はだ缶')));
      expect(theme.textTheme.bodyMedium!.fontFamily, typeface.fontFamily);
      expect(theme.textTheme.bodyMedium!.fontWeight, FontWeight.w500);
      expect(theme.textTheme.titleLarge!.fontWeight, FontWeight.w500);
      _expectTypeface(tester, find.text('はだ缶'), typeface);
      final buttonText = find.descendant(
        of: find.byKey(const Key('create-room')),
        matching: find.byType(Text),
      );
      _expectTypeface(tester, buttonText, typeface);
      demo.createRoom(const Duration(minutes: 5));
      demo.setProfile(nickname: '表示の確認', hobby: '写真');
      expect(demo.saveProfile(), isNull);
      demo.startEvent();
      final peer = demo.peers.firstWhere(
        (person) => person.team != demo.self.team,
      );
      demo.openPairing();
      demo.selectPeer(peer.id);
      demo.confirmPeer();
      demo.injectOutcome(Outcome.win);
      await tester.pumpAndSettle();
      _expectTypeface(tester, find.text('ツナがった！'), typeface);
      _expectTypeface(
        tester,
        find.text('${peer.profile.nickname}の子分が仲間入り！'),
        typeface,
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('書体を替えてもOSの太字・文字2倍を保ち、ラベルの計測と実文字が一致する', (tester) async {
    _phone(tester);
    for (final typeface in TsunagunTypeface.values) {
      await tester.pumpWidget(_can(typeface, bold: true));
      await tester.pumpAndSettle();
      _expectLabelBounds(tester);
      _expectTypeface(
        tester,
        find.text(_longProfile.nickname),
        typeface,
        weight: FontWeight.bold,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
