import 'package:flutter/material.dart';

import '../../../models/topic.dart';

// インデックスは_netaAssetsUshiroと対応させ、同じトピックが
// 前レーン・奥レーンで同じネタになるようにする。
const _netaAssets = [
  'assets/images/sa-monn.png', // サーモン
  'assets/images/maguro.png', // まぐろ
  'assets/images/tamago.png', // たまご
  'assets/images/ebi.png', // えび
  'assets/images/ika.png', // いか
  'assets/images/ikura.png', // いくら
];

const _netaAssetsUshiro = [
  'assets/images/sa-mo_ushiro.png', // サーモン
  'assets/images/maguro_ushiro.png', // まぐろ
  'assets/images/tamago_ushiro.png', // たまご
  'assets/images/ebi_ushiro.png', // えび
  'assets/images/ika_ushiro.png', // いか
  'assets/images/ikura_ushiro.png', // いくら
];

/// くら寿司のような半透明カプセルに入った寿司ネタ(話題)。タップで話題が開く。
class SushiCapsule extends StatelessWidget {
  const SushiCapsule({
    super.key,
    required this.topic,
    required this.onTap,
    this.ushiro = false,
    this.size = const Size(100, 70),
  });

  final Topic topic;
  final VoidCallback onTap;

  /// 奥レーン(大将の背後)を通るときは、後ろ向きの画像を使う。
  final bool ushiro;

  final Size size;

  String get _netaAsset {
    final assets = ushiro ? _netaAssetsUshiro : _netaAssets;
    return assets[topic.id.hashCode.abs() % assets.length];
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
