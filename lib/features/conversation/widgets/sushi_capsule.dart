import 'package:flutter/material.dart';

import '../../../models/topic.dart';

// ベルト上での固定の並び順: たまご→サーモン→いか→えび→まぐろ→繰り返し。
// インデックスは_netaAssetsUshiroと対応させ、同じ位置なら前レーン・奥
// レーンで同じネタになるようにする。
const _netaAssets = [
  'assets/images/tamago.png', // たまご
  'assets/images/sa-monn.png', // サーモン
  'assets/images/ika.png', // いか
  'assets/images/ebi.png', // えび
  'assets/images/maguro.png', // まぐろ
];

const _netaAssetsUshiro = [
  'assets/images/tamago_ushiro.png', // たまご
  'assets/images/sa-mo_ushiro.png', // サーモン
  'assets/images/ika_ushiro.png', // いか
  'assets/images/ebi_ushiro.png', // えび
  'assets/images/maguro_ushiro.png', // まぐろ
];

/// くら寿司のような半透明カプセルに入った寿司ネタ(話題)。タップで話題が開く。
class SushiCapsule extends StatelessWidget {
  const SushiCapsule({
    super.key,
    required this.topic,
    required this.onTap,
    required this.netaIndex,
    this.ushiro = false,
    this.size = const Size(100, 70),
  });

  final Topic topic;
  final VoidCallback onTap;

  /// ベルト上の位置。たまご→サーモン→いか→えび→まぐろの固定順で
  /// ネタを決めるために使う(トピックのハッシュ値だと同じネタが
  /// 連続することがあったため)。
  final int netaIndex;

  /// 奥レーン(大将の背後)を通るときは、後ろ向きの画像を使う。
  final bool ushiro;

  final Size size;

  String get _netaAsset {
    final assets = ushiro ? _netaAssetsUshiro : _netaAssets;
    return assets[netaIndex % assets.length];
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Image.asset(_netaAsset, fit: BoxFit.contain),
      ),
    );
  }
}
