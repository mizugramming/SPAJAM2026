import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spajam2026/domain/models.dart';
import 'package:spajam2026/features/duel/race_field.dart';

const self = Participant(
  id: 'self',
  profile: Profile(nickname: 'わたし', hobby: '', comment: ''),
  team: Team.red,
);
const peer = Participant(
  id: 'peer',
  profile: Profile(nickname: 'あいて', hobby: '', comment: ''),
  team: Team.blue,
);

const redFish = 'assets/characters/hikareruaka.png';

Finder assetImage(String asset) => find.byWidgetPredicate((widget) {
  // 綱の継ぎ足し（rope-segment）は除き、魚の本体だけを探す。
  if (widget is! Image || widget.key == const Key('rope-segment')) {
    return false;
  }
  final image = widget.image;
  return image is AssetImage && image.assetName == asset;
});

double mouthY(WidgetTester tester, String asset) {
  final rect = tester.getRect(assetImage(asset));
  return rect.top + rect.height * 1496 / 1536;
}

double landingY(WidgetTester tester) =>
    tester.getRect(find.byKey(const Key('landing-line'))).center.dy;

Future<void> pumpField(
  WidgetTester tester, {
  required Size size,
  required double landingRatio,
  double depth = 0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: RaceField(
        self: self,
        peer: peer,
        selfDepth: depth,
        peerDepth: depth,
        landingRatio: landingRatio,
      ),
    ),
  );
}

/// 綱の上端のy。継ぎ足した綱を含め、その魚の画像のいちばん上。
double ropeTop(WidgetTester tester, String asset) {
  final images = find.byWidgetPredicate((widget) {
    if (widget is! Image) return false;
    final image = widget.image;
    return image is AssetImage && image.assetName == asset;
  });
  return images
      .evaluate()
      .map((element) => tester.getRect(find.byWidget(element.widget)).top)
      .reduce((a, b) => a < b ? a : b);
}

void main() {
  testWidgets('吊られた魚の2枚は登録済みの素材として読み込める', (tester) async {
    for (final asset in [redFish, 'assets/characters/hikareruao.png']) {
      final data = await rootBundle.load(asset);
      expect(data.lengthInBytes, greaterThan(0), reason: asset);
    }
  });

  testWidgets('線の高さは割合で決まり、深さ1で魚の口先がその線に付く', (tester) async {
    const size = Size(412, 900);
    for (final ratio in [0.45, 0.7, 0.9]) {
      await pumpField(tester, size: size, landingRatio: ratio, depth: 1);
      expect(landingY(tester), closeTo(size.height * ratio, 1e-6));
      expect(mouthY(tester, redFish), closeTo(landingY(tester), 1e-6));
    }
  });

  testWidgets('線を高くしすぎても、吊り始めの魚の下に落ちる距離を残す', (tester) async {
    await pumpField(tester, size: const Size(360, 640), landingRatio: 0.1);
    // 吊り始め（深さ0）の口先より、線が十分下にある。
    expect(landingY(tester), greaterThan(mouthY(tester, redFish) + 40));
  });

  testWidgets('線の高さに関わらず、綱の上端は画面の上端から切れない', (tester) async {
    for (final ratio in [0.4, RaceField.defaultLandingRatio, 0.95]) {
      await pumpField(
        tester,
        size: const Size(412, 900),
        landingRatio: ratio,
        depth: RaceField.maxDepth,
      );
      expect(ropeTop(tester, redFish), lessThanOrEqualTo(0), reason: '$ratio');
    }
  });
}
