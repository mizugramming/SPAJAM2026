import 'dart:math';

import 'package:flutter/foundation.dart';

/// 魂を運ぶ1回分（レベル）の速さと、押せる幅。
///
/// レベルが上がるほど、缶から缶へ速く飛び、押せる幅がせまくなる。
@immutable
class SoulLevel {
  const SoulLevel({
    required this.number,
    required this.flight,
    required this.window,
    required this.partnerMissRate,
  });

  /// 1から始まるレベル番号。クリアしたときの魂ポイントにも使う。
  final int number;

  /// 缶から次の缶（最後は穴）へ飛ぶ時間。
  final Duration flight;

  /// 魂が缶に着く時刻の前後、この幅の間に押せば運べる。
  final Duration window;

  /// 仮想の相方が、自分の缶で押しそこねる確率。
  final double partnerMissRate;

  /// クリアで得る魂ポイント（レベル1は1pt、2は2pt、3は3pt）。
  int get points => number;

  /// 上から降りて、最初の缶に着くまでの時間。
  Duration get firstArrival => flight * 1.3;

  static const all = <SoulLevel>[
    SoulLevel(
      number: 1,
      flight: Duration(milliseconds: 1000),
      window: Duration(milliseconds: 230),
      partnerMissRate: 0,
    ),
    SoulLevel(
      number: 2,
      flight: Duration(milliseconds: 800),
      window: Duration(milliseconds: 190),
      partnerMissRate: 0.05,
    ),
    SoulLevel(
      number: 3,
      flight: Duration(milliseconds: 650),
      window: Duration(milliseconds: 150),
      partnerMissRate: 0.10,
    ),
  ];
}

/// 場面ごとの待ち時間。
abstract final class SoulTiming {
  /// 「レベルN」を見せてから魂が降り始めるまで。
  static const intro = Duration(milliseconds: 1200);

  /// 穴に入って小さくなる時間。
  static const holeSink = Duration(milliseconds: 350);

  /// レベルクリアを見せてから次へ進むまで（穴に入り終えた後）。
  static const clearLinger = Duration(milliseconds: 900);

  /// 魂が海へ落ちる時間と、その後に見せておく時間。
  static const fall = Duration(milliseconds: 800);
  static const fallLinger = Duration(milliseconds: 700);

  /// 最後の結果を見せてから、親へ通知するまで。
  static const finalPanel = Duration(milliseconds: 1800);
}

enum SoulStatus { flying, cleared, fell }

enum SoulTapKind {
  /// 缶に間に合って、魂を運べた。
  carried,

  /// 早すぎ、または相方の番に押して、魂が海へ落ちた。
  fell,

  /// 終わった後や、自分の番がもう無いときの操作。何も起きない。
  ignored,
}

@immutable
class SoulTapResult {
  const SoulTapResult(this.kind, {this.offset, this.just = false});

  final SoulTapKind kind;

  /// 魂が缶に着く時刻からのずれ（運べたときだけ）。
  final Duration? offset;

  /// ほぼぴったり（押せる幅の3分の1以内）だった。
  final bool just;
}

/// レベル1回分の進行。魂が右の缶、左の缶、右の缶…と6回運ばれて穴へ入るまで。
///
/// 奇数番の缶（右）はあなた、偶数番の缶（左）は相方が押す。時刻は
/// 魂を放した時点からの経過時間で、画面の描画や時計は持たない。
class SoulRun {
  SoulRun({required this.level, required List<Duration?> partnerOffsets})
    : partnerOffsets = List.unmodifiable(partnerOffsets),
      assert(
        partnerOffsets.length == partnerHops,
        'partnerOffsets must have $partnerHops entries',
      );

  /// 缶の数（左右3つずつ）。
  static const hops = 6;

  /// 自分の最後の缶（5番）。これを運んだ後、自分の番はない。
  static const lastSelfHop = 5;

  static const partnerHops = hops ~/ 2;

  final SoulLevel level;

  /// 相方が押した時刻の、缶に着く時刻からのずれ。null は押しそこね。
  final List<Duration?> partnerOffsets;

  SoulStatus _status = SoulStatus.flying;
  int _nextHop = 1;
  Duration? _failedAt;
  int? _failedHop;

  SoulStatus get status => _status;

  /// 次に運ぶ缶（1〜6）。すべて運んだら7。
  int get nextHop => _nextHop;

  int get carriedHops => _nextHop - 1;

  /// 落ちた時刻と缶。落ちていなければ null。
  Duration? get failedAt => _failedAt;
  int? get failedHop => _failedHop;

  bool isSelfHop(int hop) => hop.isOdd;

  /// [hop]番目の缶に魂が着く時刻。
  Duration arrival(int hop) => level.firstArrival + level.flight * (hop - 1);

  /// 6番目の缶から飛んで、穴に着く時刻。
  Duration get holeArrival => arrival(hops) + level.flight;

  bool _partnerCarries(Duration? offset) =>
      offset != null && offset.abs() <= level.window;

  void _fail(int hop, Duration at) {
    _status = SoulStatus.fell;
    _failedAt = at;
    _failedHop = hop;
  }

  /// 時刻 [t] までに起きること（相方が運ぶ・見のがす・穴に着く）を進める。
  void advance(Duration t) {
    while (_status == SoulStatus.flying) {
      if (_nextHop > hops) {
        if (t >= holeArrival) _status = SoulStatus.cleared;
        return;
      }
      final hop = _nextHop;
      final due = arrival(hop) + level.window;
      if (isSelfHop(hop)) {
        // 自分の番。幅を過ぎても押されなければ見のがし。
        if (t > due) _fail(hop, due);
        return;
      }
      final offset = partnerOffsets[hop ~/ 2 - 1];
      if (!_partnerCarries(offset)) {
        if (t > due) _fail(hop, due);
        return;
      }
      if (t >= arrival(hop) + offset!) {
        _nextHop++;
        continue;
      }
      return;
    }
  }

  /// 自分のタップ。押した時刻 [t] が、次の自分の缶の幅に入っていれば運べる。
  SoulTapResult tap(Duration t) {
    advance(t);
    if (_status != SoulStatus.flying || _nextHop > lastSelfHop) {
      return const SoulTapResult(SoulTapKind.ignored);
    }
    final hop = _nextHop;
    if (!isSelfHop(hop)) {
      // 相方の番に押した（おてつき）。
      _fail(hop, t);
      return const SoulTapResult(SoulTapKind.fell);
    }
    final offset = t - arrival(hop);
    if (offset.abs() <= level.window) {
      _nextHop++;
      return SoulTapResult(
        SoulTapKind.carried,
        offset: offset,
        just: offset.abs() * 3 <= level.window,
      );
    }
    // 幅より遅い場合は advance が見のがしとして落としている。ここは早すぎ。
    _fail(hop, t);
    return const SoulTapResult(SoulTapKind.fell);
  }
}

/// 仮想の相方（左の缶を受け持つ）が、そのレベルで押す時刻のずれを決める。
typedef PartnerOffsets = List<Duration?> Function(SoulLevel level);

/// 一台デモの仮想の相方。幅の半分の範囲でばらつき、たまに押しそこねる。
/// 将来の実通信では、相手の端末からのタップ時刻に差し替えられる。
class SoulPartner {
  SoulPartner([Random? random]) : _random = random ?? Random();

  final Random _random;

  List<Duration?> offsetsFor(SoulLevel level) {
    return List.generate(SoulRun.partnerHops, (_) {
      if (_random.nextDouble() < level.partnerMissRate) return null;
      final spread = level.window.inMilliseconds * 0.5;
      return Duration(
        milliseconds: (spread * (_random.nextDouble() * 2 - 1)).round(),
      );
    });
  }
}
