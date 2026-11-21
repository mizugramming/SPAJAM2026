import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../game/game.dart';
import 'layout_tuner.dart';
import 'sandpaper.dart';
import 'surface_art.dart';
import 'workshop_theme.dart';

export 'workshop_theme.dart' show workshopTheme;

abstract interface class WorkshopActions {
  void choose(WorkMaterial material);
  void capture();
  void start();
  void retry();
  void simulateStroke();
  void openDiagnostics();
  void selectDemoPitch(double hz);
  void useVoiceMode(VoiceMode mode);
  double get demoPitch;
}

/// 各画面の部品を lib/ui/workshop_layout.dart の配置表どおりに置く。
class Workshop extends StatelessWidget {
  const Workshop({
    super.key,
    required this.game,
    required this.actions,
    required this.simulated,
    required this.busy,
    required this.error,
    required this.voiceMode,
    this.inContact = false,
    this.onEnter,
    this.onTitle,
  });

  final GameController game;
  final WorkshopActions actions;
  final bool simulated;
  final bool busy;
  final String? error;
  final VoiceMode voiceMode;
  final bool inContact;
  final VoidCallback? onEnter;

  /// プレイを初期化してタイトル画面へ戻す。素材選択の「戻る」と結果の「タイトルへ」で使う。
  final VoidCallback? onTitle;

  @override
  Widget build(BuildContext context) {
    final start = onEnter;
    if (start == null || game.phase != GamePhase.select) return _game(context);
    return Scaffold(
      body: SafeArea(
        child: LayoutStage(
          key: const ValueKey('title'),
          screen: Screen.title,
          parts: _titleParts(start),
          background: const _Background(),
        ),
      ),
    );
  }

  List<Part> _titleParts(VoidCallback start) => [
    Part(
      'logo',
      'タイトル文字',
      Semantics(
        header: true,
        label: 'いろみがき',
        child: ExcludeSemantics(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topLeft,
            child: _GrungeText(
              'いろ\nみがき',
              style: TextStyle(
                color: chalk,
                fontSize: 96,
                fontWeight: FontWeight.w900,
                height: 1.0,
                letterSpacing: -2,
              ),
            ),
          ),
        ),
      ),
      fill: true,
    ),
    const Part(
      'tagline',
      '英字の添え書き',
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.topLeft,
        child: Text(
          'POLISH  OUT  YOUR  COLOR',
          maxLines: 1,
          style: TextStyle(
            color: chalk,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
          ),
        ),
      ),
      fill: true,
    ),
    const Part(
      'catch',
      '縦書きの一言',
      _VerticalText(
        '色を磨き出せ',
        style: TextStyle(
          color: chalk,
          fontSize: 34,
          fontWeight: FontWeight.w800,
          height: 1.15,
        ),
      ),
      align: Alignment.topCenter,
    ),
    Part(
      'medal',
      'メダル',
      ExcludeSemantics(child: _MedalImage(_medalStageImages.first)),
      fill: true,
    ),
    Part(
      'start',
      '「はじめる」ボタン',
      _BoxButton(
        key: const ValueKey('title-start'),
        icon: Icons.local_fire_department_rounded,
        label: 'はじめる',
        onPressed: start,
      ),
      fill: true,
    ),
  ];

  Widget _game(BuildContext context) {
    final screen = switch (game.phase) {
      GamePhase.select => Screen.select,
      GamePhase.voice => Screen.voice,
      GamePhase.ready => Screen.ready,
      GamePhase.polishing => Screen.polishing,
      GamePhase.result => Screen.result,
    };
    final hasPaper = screen == Screen.ready || screen == Screen.polishing;
    final header = Part(
      'header',
      'ロゴ行',
      _Header(
        onDiagnostics: screen == Screen.select ? actions.openDiagnostics : null,
        simulated: simulated,
      ),
    );
    final stage = screen == Screen.select
        ? _SelectStage(
            key: ValueKey((game.phase, game.round)),
            header: header,
            onBack: onTitle,
            onChoose: (material) {
              unawaited(precacheImage(SandpaperFace.texture, context));
              actions.choose(material);
            },
          )
        : LayoutStage(
            key: ValueKey((game.phase, game.round)),
            screen: screen,
            background: _Background(subdued: hasPaper),
            parts: [
              if (!hasPaper) header,
              Part('round', 'ラウンド行', _RoundHeader(game: game)),
              Part(
                'workpiece',
                '素材',
                _Workpiece(game: game, inContact: inContact),
                fill: true,
              ),
              ..._controls(context),
            ],
          );
    return Scaffold(
      body: SafeArea(
        child: screen == Screen.ready
            ? _PaperArrival(key: ValueKey(game.round), child: stage)
            : stage,
      ),
    );
  }

  Part _paper({bool arriving = false}) => Part(
    'paper',
    '紙やすり',
    SandpaperFace(
      grit: game.grit!,
      sample: game.sample!,
      progress: game.progress,
      strokes: game.totalStrokes,
      inContact: inContact,
    ),
    transition: arriving ? _paperEntrance : null,
    fill: true,
  );

  List<Part> _controls(BuildContext context) {
    final errorText = error;
    final errorPart = Part(
      'error',
      'エラー文',
      errorText == null || errorText.isEmpty
          ? null
          : Semantics(
              liveRegion: true,
              child: Text(
                errorText,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  backgroundColor: game.phase == GamePhase.voice ? null : bench,
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
            ),
    );
    switch (game.phase) {
      case GamePhase.select:
        return [];
      case GamePhase.voice:
        final voiceHint = voiceMode == VoiceMode.pitch
            ? '低い声は粗目、高い声は細目。'
            : '小さな声は粗目、大きな声は細目。';
        return [
          // 1回目だけ素材選択へ戻れる。選んでいた素材を表示した状態で戻る。
          Part(
            'back',
            '「戻る」ボタン',
            game.round == 1
                ? _BackButton(onPressed: busy ? null : actions.retry)
                : null,
          ),
          Part(
            'body',
            '声の出し方',
            _Body(simulated ? voiceHint : 'スマホを机に置いて「あー」とひと声。$voiceHint'),
          ),
          Part('title', '見出し', _Title(busy ? '声を聞いています' : 'やすりを作る')),
          Part(
            'chips',
            '疑似音声の選択',
            !simulated
                ? null
                : Wrap(
                    spacing: 8,
                    runSpacing: 2,
                    children: [
                      for (final choice in [
                        (110, '低い', '小'),
                        (190, '中間', '中'),
                        (300, '高い', '大'),
                      ])
                        ChoiceChip(
                          key: ValueKey('demo-${choice.$1}'),
                          label: Text(
                            voiceMode == VoiceMode.pitch
                                ? choice.$2
                                : choice.$3,
                          ),
                          selected: actions.demoPitch == choice.$1,
                          onSelected: busy
                              ? null
                              : (_) => actions.selectDemoPitch(
                                  choice.$1.toDouble(),
                                ),
                        ),
                    ],
                  ),
          ),
          errorPart,
          Part(
            'action',
            '「声を取る」ボタン',
            _InkMicButton(
              key: const ValueKey('capture'),
              label: busy
                  ? '採音中…'
                  : simulated
                  ? '疑似音声を使う'
                  : '声を取る',
              onPressed: busy ? null : actions.capture,
            ),
            fill: true,
          ),
          Part(
            'mode',
            '音量・高さの切り替え',
            Center(
              child: TextButton(
                key: const ValueKey('voice-mode'),
                onPressed: busy
                    ? null
                    : () => actions.useVoiceMode(
                        voiceMode == VoiceMode.pitch
                            ? VoiceMode.volume
                            : VoiceMode.pitch,
                      ),
                child: Text(voiceMode == VoiceMode.pitch ? '音量で選ぶ' : '声の高さで選ぶ'),
              ),
            ),
            align: Alignment.topCenter,
          ),
        ];
      case GamePhase.ready:
        return [
          Part('title', '見出し', _Title('${game.grit!.label}のやすり')),
          Part(
            'body',
            '説明文',
            _Body(simulated ? '「1往復を入力」で磨けます。' : 'スマホを持ち上げて、机と平行に構える。'),
          ),
          _paper(arriving: true),
          errorPart,
          Part(
            'action',
            '開始ボタン',
            _BoxButton(
              key: const ValueKey('start'),
              icon: Icons.play_arrow_rounded,
              label: busy ? '準備中…' : '10秒間、磨き始める',
              onPressed: busy ? null : actions.start,
            ),
            transition: _afterPaperLands,
            fill: true,
          ),
        ];
      case GamePhase.polishing:
        return [
          const Part('title', '見出し', _Title('前後に磨く')),
          Part(
            'timer',
            '残り時間と往復数',
            // 往復数が増えても折り返さず1行で出す。入りきらないときだけ横に縮める。
            Align(
              alignment: Alignment.centerLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  spacing: 16,
                  children: [
                    Text(
                      '残り ${game.remainingSeconds} 秒',
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                        color: ember,
                      ),
                    ),
                    Text(
                      '${game.grit!.label}   ·   ${game.strokes} 往復',
                      style: const TextStyle(color: muted, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Part(
            'bar',
            '時間バー',
            LayoutBuilder(
              builder: (context, box) => LinearProgressIndicator(
                value: game.remainingSeconds / 10,
                semanticsLabel: '残り時間',
                minHeight: box.maxHeight,
                backgroundColor: chalk.withValues(alpha: .20),
                color: ember,
              ),
            ),
            fill: true,
          ),
          _paper(),
          errorPart,
          Part(
            'action',
            '「1往復を入力」ボタン',
            !simulated
                ? null
                : _BoxButton(
                    key: const ValueKey('simulate-stroke'),
                    icon: Icons.swap_vert,
                    label: '1往復を入力',
                    onPressed: actions.simulateStroke,
                  ),
            fill: true,
          ),
        ];
      case GamePhase.result:
        return [
          Part('title', '見出し', _Title(_stageName(game))),
          Part(
            'body',
            '説明文',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _Body('3回の研磨で、合計${game.totalStrokes}往復しました。'),
                if (game.verdict != null) ...[
                  const SizedBox(height: 8),
                  _Body(game.verdict!),
                ],
              ],
            ),
          ),
          Part(
            'action',
            '「もう一度遊ぶ」ボタン',
            _BoxButton(
              key: const ValueKey('retry'),
              icon: Icons.replay_rounded,
              label: 'もう一度遊ぶ',
              onPressed: actions.retry,
            ),
            fill: true,
          ),
          Part('home', '「タイトルへ」ボタン', switch (onTitle) {
            final VoidCallback toTitle => _QuietButton(
              key: const ValueKey('to-title'),
              icon: Icons.home_outlined,
              label: 'タイトルへ',
              onPressed: toTitle,
            ),
            _ => null,
          }, fill: true),
        ];
    }
  }
}

/// The departure, flight and start button share a single clock per round.
class _PaperArrival extends StatelessWidget {
  const _PaperArrival({super.key, required this.child});
  final Widget child;
  static const duration = Duration(milliseconds: 600);

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      duration: reduced ? Duration.zero : duration,
      tween: Tween(begin: reduced ? 1.0 : 0.0, end: 1.0),
      child: ClipRect(child: child),
      builder: (context, t, stage) =>
          _ArrivalProgress(value: reduced ? 1 : t, child: stage!),
    );
  }
}

class _ArrivalProgress extends InheritedWidget {
  const _ArrivalProgress({required this.value, required super.child});
  final double value;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ArrivalProgress>()!.value;

  @override
  bool updateShouldNotify(_ArrivalProgress old) => value != old.value;
}

Widget _afterPaperLands(Size canvas, Rect bounds, Widget child) => Builder(
  builder: (context) =>
      _ArrivalProgress.of(context) == 1 ? child : const SizedBox.shrink(),
);

Widget _paperEntrance(Size canvas, Rect bounds, Widget child) => Builder(
  builder: (context) {
    final t = _ArrivalProgress.of(context);
    const exitEnd = 180 / 600;
    const fallStart = 220 / 600;
    final flight = const Interval(
      fallStart,
      1,
      curve: Cubic(.36, .06, .25, 1),
    ).transform(t);
    final button = layoutTuner.boxOf(Screen.voice, 'action').rectIn(canvas);
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        ExcludeSemantics(
          excluding: t < 1,
          child: Transform.translate(
            offset: Offset(0, -(bounds.bottom + 1) * (1 - flight)),
            child: child,
          ),
        ),
        if (t < exitEnd)
          Positioned.fromRect(
            rect: button
                .shift(-bounds.topLeft)
                .translate(
                  0,
                  -(button.bottom + 1) *
                      Curves.easeInCubic.transform(t / exitEnd),
                ),
            child: const ExcludeSemantics(
              child: _InkMicButton(
                key: ValueKey('voice-departure'),
                label: '採音完了',
                onPressed: null,
                recorded: true,
              ),
            ),
          ),
      ],
    );
  },
);

/// 全画面に敷く背景画像。画面の縦横比に合わせて切り抜く。
class _Background extends StatelessWidget {
  const _Background({this.subdued = false});
  final bool subdued;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Image(
      image: const AssetImage('assets/images/background.jpg'),
      color: subdued ? const Color(0xC4131010) : null,
      colorBlendMode: BlendMode.srcATop,
      fit: BoxFit.cover,
    ),
  );
}

/// 黒いかすれを重ねた文字。
class _GrungeText extends StatelessWidget {
  const _GrungeText(this.text, {required this.style});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Text(text, style: style, softWrap: false),
      Positioned.fill(
        child: IgnorePointer(
          child: CustomPaint(
            painter: _GrungePainter(text.hashCode, frame: false, density: 40),
          ),
        ),
      ),
    ],
  );
}

/// 1文字ずつ縦に並べた文字。
class _VerticalText extends StatelessWidget {
  const _VerticalText(this.text, {required this.style});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [for (final c in text.characters) Text(c, style: style)],
  );
}

/// 四角いっぱいに広がる主ボタン。文字が入りきらなければ縮める。
class _BoxButton extends StatelessWidget {
  const _BoxButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: Stack(
      fit: StackFit.expand,
      children: [
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(2)),
            ),
            textStyle: const TextStyle(
              fontFamily: appFont,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          onPressed: onPressed,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 24),
                const SizedBox(width: 10),
                Text(label),
              ],
            ),
          ),
        ),
        // 文字と地に黒いかすれを重ねる。押す操作は下のボタンへ通す。
        IgnorePointer(
          child: CustomPaint(
            painter: _GrungePainter(label.hashCode, frame: false),
          ),
        ),
      ],
    ),
  );
}

/// 朱色の丸いマイクボタン。SPAJAM UI Arsenal の「いろみがきの音声ボタン」
/// （2026-11-22確認）の形・色・影・押し込みを描き直したもの。にじみ画像は使わず、
/// かすれの質感で代える。採音は途中で止められないため、採音中は薄くして押せなくする。
class _InkMicButton extends StatefulWidget {
  const _InkMicButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.recorded = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool recorded;

  @override
  State<_InkMicButton> createState() => _InkMicButtonState();
}

class _InkMicButtonState extends State<_InkMicButton> {
  static const _face = Color(0xFFCB392C);
  static const _rim = Color(0xFF82271E);
  static const _base = Color(0xFF591F18);
  static const _ivory = Color(0xFFFFF8EC);
  bool _down = false;

  void _press(bool down) {
    if (widget.onPressed == null || _down == down) return;
    setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final pressed = _down && enabled;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.topCenter,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.label,
        onTap: widget.onPressed,
        excludeSemantics: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkResponse(
              customBorder: const CircleBorder(),
              onHighlightChanged: _press,
              onTap: widget.onPressed,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: enabled || widget.recorded ? 1 : .6,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: 76,
                  height: 76,
                  transform: Matrix4.translationValues(0, pressed ? 2 : 0, 0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _face,
                    border: Border.all(color: _rim),
                    boxShadow: pressed
                        ? const [BoxShadow(color: _base, offset: Offset(0, 1))]
                        : const [
                            BoxShadow(color: _base, offset: Offset(0, 3)),
                            BoxShadow(
                              color: Color(0x57080605),
                              offset: Offset(0, 6),
                              blurRadius: 10,
                            ),
                          ],
                  ),
                  child: ClipOval(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // 上の照り返しと下の陰（見本の内側の影）。
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: pressed
                                  ? const [Color(0x3368231C), Color(0x00000000)]
                                  : const [
                                      Color(0x57FA7559),
                                      Color(0x00000000),
                                      Color(0x00000000),
                                      Color(0x8585251B),
                                    ],
                              stops: pressed ? null : const [0, .12, .85, 1],
                            ),
                          ),
                        ),
                        CustomPaint(
                          painter: _GrungePainter(
                            widget.label.hashCode ^ 0x1177,
                            frame: false,
                            density: 60,
                          ),
                        ),
                        const Center(
                          child: CustomPaint(
                            size: Size(28, 34),
                            painter: _MicPainter(color: _ivory),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.label,
              style: const TextStyle(
                color: Color(0xFFFFF9EF),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 見本のマイク記号（28×34）。カプセル・受け皿・支柱・台座と、赤い切れ込み2本。
class _MicPainter extends CustomPainter {
  const _MicPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color;
    // 台座と支柱。
    canvas.drawRect(Rect.fromLTWH(7, 31, 14, 3), fill);
    canvas.drawRect(Rect.fromLTWH(12.5, 26, 3, 8), fill);
    // カプセル。
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(7, 0, 14, 22),
        const Radius.circular(9),
      ),
      fill,
    );
    // カプセル右側の切れ込み。
    final slit = Paint()..color = const Color(0xFFA93227);
    for (final top in [6.0, 10.0]) {
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(16, top, 5, 2),
          topLeft: const Radius.circular(1),
          bottomLeft: const Radius.circular(1),
        ),
        slit,
      );
    }
    // 受け皿（上の開いたU字）。
    final cradle = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final path = Path()
      ..moveTo(2.5, 13)
      ..lineTo(2.5, 14)
      ..arcToPoint(
        const Offset(25.5, 14),
        radius: const Radius.circular(11.5),
        clockwise: false,
      )
      ..lineTo(25.5, 13);
    canvas.drawPath(path, cradle);
  }

  @override
  bool shouldRepaint(_MicPainter old) => old.color != color;
}

/// かすれ・ひっかき傷の質感。模様はボタンごとに固定。
class _GrungePainter extends CustomPainter {
  _GrungePainter(this.seed, {this.frame = true, this.density = 90});
  final int seed;

  /// 縁を暗くするか（ボタン用）。
  final bool frame;

  /// 小さいほど点が多い（1点あたりの面積）。
  final double density;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final random = math.Random(seed);
    canvas.clipRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(2)),
    );
    final speck = Paint()..color = bench.withValues(alpha: .55);
    final count = (size.width * size.height / density).clamp(20, 1600).toInt();
    for (var i = 0; i < count; i++) {
      final r = random.nextDouble() * 1.4 + .3;
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        r,
        speck,
      );
    }
    final scratch = Paint()
      ..color = bench.withValues(alpha: .45)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 14; i++) {
      final start = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      final length = random.nextDouble() * size.width * .18 + 4;
      final angle = (random.nextDouble() - .5) * .5;
      scratch.strokeWidth = random.nextDouble() * 1.4 + .4;
      canvas.drawLine(
        start,
        start + Offset(math.cos(angle), math.sin(angle)) * length,
        scratch,
      );
    }
    // 縁を少し暗くして、刷ったような端にする。
    if (!frame) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = bench.withValues(alpha: .35),
    );
  }

  @override
  bool shouldRepaint(_GrungePainter old) =>
      old.seed != seed || old.frame != frame || old.density != density;
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text,
      style: const TextStyle(
        color: chalk,
        fontSize: 28,
        fontWeight: FontWeight.w800,
        height: 1.22,
        letterSpacing: -.75,
      ),
    ),
  );
}

class _Body extends StatelessWidget {
  const _Body(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(color: muted, fontSize: 15, height: 1.55),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.onDiagnostics, required this.simulated});
  final VoidCallback? onDiagnostics;
  final bool simulated;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      const _FileMark(),
      const SizedBox(width: 9),
      const Expanded(
        child: Text(
          'いろみがき',
          style: TextStyle(
            fontSize: 17,
            letterSpacing: 1.0,
            color: chalk,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      if (simulated)
        const Text('疑似入力', style: TextStyle(fontSize: 12, color: muted)),
      if (onDiagnostics != null)
        IconButton(
          key: const ValueKey('diagnostics'),
          tooltip: '端末の入力と振動を確認',
          onPressed: onDiagnostics,
          icon: const Icon(Icons.tune_rounded, size: 21, color: muted),
        ),
    ],
  );
}

class _FileMark extends StatelessWidget {
  const _FileMark();
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 26,
    child: CustomPaint(painter: _FilePainter()),
  );
}

class _FilePainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    c.translate(s.width / 2, s.height / 2);
    c.rotate(-math.pi / 4);
    final p = Paint()..color = crimson;
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-11, -7, 17, 14),
        const Radius.circular(2),
      ),
      p,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4, -2.2, 9, 4.4),
        const Radius.circular(2),
      ),
      p,
    );
    final notch = Paint()
      ..color = bench
      ..strokeWidth = 1.2;
    for (final x in [-8.0, -4.0, 0.0]) {
      c.drawLine(Offset(x, -4), Offset(x + 2, 4), notch);
    }
  }

  @override
  bool shouldRepaint(_FilePainter oldDelegate) => false;
}

/// メダルの段階ごとの画像。順番は game.dart の段階（サビた銅・銅・銀・金）に対応。
/// 銅の2段階は同じ絵にゲームの研磨率に応じた地金色・サビ・光沢を重ねる。
const _medalStageImages = [
  'assets/fonts/daou.jpg',
  'assets/fonts/daou.jpg',
  'assets/fonts/gin.jpg',
  'assets/fonts/kin.jpg',
];

/// 金をほぼ磨き切ったときの画像と、その研磨の割合。
const _medalShineImage = 'assets/fonts/kinpika.jpg';
const _medalShineFrom = .95;

/// 素材と研磨の割合に合う画像。画像のない素材は null（描画で表示する）。
String? _imageFor(WorkMaterial material, double progress) {
  if (material.id != 'medal') return null;
  if (progress >= _medalShineFrom) return _medalShineImage;
  var index = 0;
  for (var i = 0; i < material.stages.length; i++) {
    if (progress >= material.stages[i].threshold) index = i;
  }
  return _medalStageImages[index.clamp(0, _medalStageImages.length - 1)];
}

/// 仕上がり画面に出す段階名。金ピカの画像になるほど磨いたメダルは「金ピカのメダル」と呼ぶ。
String _stageName(GameController game) {
  final material = game.material;
  if (material != null &&
      _imageFor(material, game.progress) == _medalShineImage) {
    return '金ピカのメダル';
  }
  return game.stage.name;
}

/// 円形に切り抜いたメダル画像。画像が替わるときは重ねて切り替える。
class _MedalImage extends StatelessWidget {
  const _MedalImage(this.image, {this.cacheWidth = 720, this.copperTint});
  final String image;
  final int cacheWidth;
  final Color? copperTint;

  @override
  Widget build(BuildContext context) => Center(
    child: AspectRatio(
      aspectRatio: 1,
      child: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 450),
        child: ClipOval(
          key: ValueKey(image),
          child: Image.asset(
            image,
            fit: BoxFit.cover,
            cacheWidth: cacheWidth,
            color: copperTint,
            colorBlendMode: BlendMode.srcATop,
          ),
        ),
      ),
    ),
  );
}

/// 素材ごとの見出し。素材選択で画像のすぐ上に出す。
String _pickHeading(WorkMaterial material) => switch (material.id) {
  'medal' => 'メダルを磨く',
  'kanji' => '漢字を磨く',
  _ => '${material.name}を磨く',
};

/// 素材選択画面。横スワイプでぐるぐる回る回転式で素材を見せ、「これを磨く」で確定する。
/// 見出し・中央の画像・確定はすべて同じ番号 [_index] を指す。
/// 表示中のページは PageStorage に残し、採音画面から戻ったときも同じ素材を出す。
class _SelectStage extends StatefulWidget {
  const _SelectStage({
    super.key,
    required this.header,
    required this.onBack,
    required this.onChoose,
  });
  final Part header;
  final VoidCallback? onBack;
  final void Function(WorkMaterial material) onChoose;

  @override
  State<_SelectStage> createState() => _SelectStageState();
}

class _SelectStageState extends State<_SelectStage> {
  static const _pageId = 'material-page';

  /// 端のないくり返しにするため、十分大きなページ番号から始める。
  static final _loopBase = materials.length * 1000;
  late int _index;
  late final PageController _pages;

  @override
  void initState() {
    super.initState();
    final saved = PageStorage.maybeOf(
      context,
    )?.readState(context, identifier: _pageId);
    _index = saved is int ? saved % materials.length : 0;
    _pages = PageController(
      initialPage: _loopBase + _index,
      viewportFraction: .76,
    );
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _show(int page) {
    final index = page % materials.length;
    PageStorage.maybeOf(
      context,
    )?.writeState(context, index, identifier: _pageId);
    setState(() => _index = index);
  }

  void _turn(int page) => _pages.animateToPage(
    page,
    duration: MediaQuery.disableAnimationsOf(context)
        ? const Duration(milliseconds: 1)
        : const Duration(milliseconds: 360),
    curve: Curves.easeOutCubic,
  );

  int get _page => _pages.hasClients
      ? (_pages.page ?? _pages.initialPage.toDouble()).round()
      : _loopBase + _index;

  @override
  Widget build(BuildContext context) {
    final current = materials[_index];
    final next = materials[(_index + 1) % materials.length];
    final previous = materials[(_index - 1) % materials.length];
    return LayoutStage(
      screen: Screen.select,
      background: const _Background(),
      parts: [
        widget.header,
        Part('back', '「戻る」ボタン', switch (widget.onBack) {
          final VoidCallback back => _BackButton(onPressed: back),
          _ => null,
        }),
        const Part('title', '見出し', _Title('磨く素材を選ぶ')),
        Part(
          'heading',
          '素材の見出し',
          Semantics(
            liveRegion: true,
            child: Text(
              _pickHeading(current),
              key: const ValueKey('material-heading'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: chalk,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
                height: 1.2,
              ),
            ),
          ),
          align: Alignment.topCenter,
        ),
        Part(
          'pager',
          '素材画像（左右にスワイプで回る）',
          Semantics(
            label: '素材の選択',
            value: _pickHeading(current),
            increasedValue: _pickHeading(next),
            decreasedValue: _pickHeading(previous),
            onIncrease: () => _turn(_page + 1),
            onDecrease: () => _turn(_page - 1),
            // マウスのドラッグでも回せるようにする（Chromeでの確認用）。
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
              child: PageView.builder(
                key: const ValueKey('material-pager'),
                controller: _pages,
                onPageChanged: _show,
                clipBehavior: Clip.none,
                itemBuilder: (context, page) {
                  final material = materials[page % materials.length];
                  return ExcludeSemantics(
                    child: _CarouselItem(
                      key: ValueKey('material-page-${material.id}-$page'),
                      controller: _pages,
                      page: page,
                      fallbackPage: _loopBase + _index,
                      onTap: () => _turn(page),
                      child: _MaterialArt(material: material),
                    ),
                  );
                },
              ),
            ),
          ),
          fill: true,
        ),
        Part(
          'confirm',
          '「これを磨く」ボタン',
          Semantics(
            hint: '${_pickHeading(current)}。左右にスワイプすると素材を切り替えられます',
            child: _BoxButton(
              key: const ValueKey('confirm-material'),
              icon: Icons.check_rounded,
              label: 'これを磨く',
              onPressed: () => widget.onChoose(current),
            ),
          ),
          fill: true,
        ),
      ],
    );
  }
}

/// 回転式の1枚。中央から離れるほど小さく暗くし、タップで中央へ回す。
class _CarouselItem extends StatelessWidget {
  const _CarouselItem({
    super.key,
    required this.controller,
    required this.page,
    required this.fallbackPage,
    required this.onTap,
    required this.child,
  });
  final PageController controller;
  final int page;
  final int fallbackPage;
  final VoidCallback onTap;
  final Widget child;

  /// 左右の素材を中央へ寄せる量（1枚の幅に対する割合）。中央の素材とは重ねない。
  static const _pull = .18;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final position =
            controller.hasClients && controller.position.haveDimensions
            ? controller.page ?? fallbackPage.toDouble()
            : fallbackPage.toDouble();
        final offset = (page - position).clamp(-1.0, 1.0);
        final distance = offset.abs();
        final scale = 1 - .38 * distance;
        final shade = .62 * distance;
        return Transform.translate(
          offset: Offset(-offset * _pull * box.maxWidth, 0),
          child: Transform.scale(
            scale: scale,
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: shade),
                BlendMode.srcATop,
              ),
              child: child,
            ),
          ),
        );
      },
      child: GestureDetector(onTap: onTap, child: child),
    ),
  );
}

/// 素材選択で大きく見せる素材の絵。メダルは画像、ほかは描画した見本。
class _MaterialArt extends StatelessWidget {
  const _MaterialArt({required this.material});
  final WorkMaterial material;

  @override
  Widget build(BuildContext context) => Center(
    child: AspectRatio(
      aspectRatio: 1,
      child: switch (_imageFor(material, 0)) {
        final String image => _MedalImage(image, cacheWidth: 640),
        _ => SurfaceArt(material: material, progress: 1),
      },
    ),
  );
}

/// ヘッダー直下の左に置く「‹ 戻る」。
class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      key: const ValueKey('back'),
      style: TextButton.styleFrom(
        foregroundColor: chalk,
        padding: const EdgeInsets.only(left: 4, right: 12),
        textStyle: const TextStyle(
          fontFamily: appFont,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.chevron_left_rounded, size: 26),
      label: const Text('戻る', softWrap: false),
    ),
  );
}

/// 主ボタンより控えめな、枠線だけのボタン。
class _QuietButton extends StatelessWidget {
  const _QuietButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: chalk,
        backgroundColor: bench.withValues(alpha: .55),
        side: BorderSide.none,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(2)),
        ),
        textStyle: const TextStyle(
          fontFamily: appFont,
          fontSize: 16,
          fontWeight: FontWeight.w800,
          letterSpacing: 2,
        ),
      ),
      onPressed: onPressed,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    ),
  );
}

/// メダルの削りかす。往復数が増えた瞬間に1回、メダルの縁から外へ飛ばして消す。
/// 銅は画像の色のまま、銀・金は [tint] の色に塗り直す。
/// 添付の粉の画像を薄い軌跡として流し、同じ画像から切り出した赤茶・青緑の破片を
/// 数粒、角度・速さ・回転を変えて飛ばす。位置・大きさは表示中のメダル
/// （置き場所の短い辺を直径とする中央の円）を基準にする。
class _Shavings extends StatefulWidget {
  const _Shavings({
    required this.strokes,
    required this.active,
    this.tint,
    this.grit,
  });
  final int strokes;
  final bool active;

  /// やすりの目。粗目ほど大きな破片を少なく、細目ほど細かな粒を多く飛ばす。
  final Grit? grit;

  /// 削りかすを塗り直す色。null なら画像の色（銅の赤茶・青緑）のまま。
  final Color? tint;

  @override
  State<_Shavings> createState() => _ShavingsState();
}

typedef _Flake = ({
  AssetImage image,
  double spread,
  double distance,
  double spin,
  double size,
  double fall,
});

typedef _Burst = ({
  AnimationController controller,
  double angle,
  double trailScale,
  List<_Flake> flakes,
});

/// やすりの目ごとの削りかす（破片の大きさ・粒の数・飛ぶ距離・粉の軌跡の大きさ）。
({double size, int count, double reach, double trail}) _shavingsFor(
  Grit? grit,
) => switch (grit) {
  Grit.coarse => (size: 1.5, count: 4, reach: 1.2, trail: 1.15),
  Grit.fine => (size: .6, count: 7, reach: .85, trail: .85),
  _ => (size: 1.0, count: 5, reach: 1.0, trail: 1.0),
};

class _ShavingsState extends State<_Shavings> with TickerProviderStateMixin {
  static const _trail = AssetImage('assets/images/shavings.png');
  static const _copper = [
    AssetImage('assets/images/shards/copper-1.png'),
    AssetImage('assets/images/shards/copper-2.png'),
    AssetImage('assets/images/shards/copper-3.png'),
    AssetImage('assets/images/shards/copper-4.png'),
  ];
  static const _teal = [
    AssetImage('assets/images/shards/teal-1.png'),
    AssetImage('assets/images/shards/teal-2.png'),
    AssetImage('assets/images/shards/teal-3.png'),
  ];

  /// 往復ごとに移る縁の位置（画面の角度。0°が右、-90°が上）。
  static const _angles = [
    -45.0,
    -135.0,
    0.0,
    180.0,
    -70.0,
    -110.0,
    25.0,
    155.0,
  ];

  /// 粉の画像の中で粉が集まっている点（幅・高さに対する割合）と、破片が散る向き。
  static const _anchor = Offset(.25, .73);
  static final _imageDirection = math.atan2(-341, 512);
  static const _aspect = 512 / 341;
  static const _trailTravel = 40.0;
  static const _trailOpacity = .55;

  /// 全体の長さと、そのうち粉の軌跡が消えるまでの長さ。
  static const _duration = Duration(milliseconds: 420);
  static const _trailShare = 300 / 420;

  final _bursts = <_Burst>[];

  @override
  void didUpdateWidget(_Shavings old) {
    super.didUpdateWidget(old);
    if (widget.active && widget.strokes > old.strokes) _burst();
  }

  void _burst() {
    final random = math.Random(widget.strokes);
    final kind = _shavingsFor(widget.grit);
    final copperCount = (kind.count * .6).round();
    final controller = AnimationController(vsync: this, duration: _duration);
    final burst = (
      controller: controller,
      angle: _angles[widget.strokes % _angles.length] * math.pi / 180,
      trailScale: kind.trail,
      flakes: [
        for (var i = 0; i < kind.count; i++)
          (
            image: i < copperCount
                ? _copper[random.nextInt(_copper.length)]
                : _teal[random.nextInt(_teal.length)],
            spread: (random.nextDouble() - .5) * 1.4,
            distance: (50 + random.nextDouble() * 60) * kind.reach,
            spin: (random.nextBool() ? 1 : -1) * (4 + random.nextDouble() * 8),
            size: (.035 + random.nextDouble() * .03) * kind.size,
            fall: 10 + random.nextDouble() * 22,
          ),
      ],
    );
    setState(() => _bursts.add(burst));
    controller.forward().whenComplete(() {
      if (!mounted) return;
      setState(() => _bursts.remove(burst));
      controller.dispose();
    });
  }

  /// 画像の明るさの模様を残して、[_Shavings.tint] の色に塗り直す。
  Widget _tinted(Widget image) {
    final tint = widget.tint;
    if (tint == null) return image;
    const k = 1.35;
    List<double> row(double c) => [
      .2126 * c * k,
      .7152 * c * k,
      .0722 * c * k,
      0,
      0,
    ];
    return ColorFiltered(
      colorFilter: ColorFilter.matrix([
        ...row(tint.r),
        ...row(tint.g),
        ...row(tint.b),
        0,
        0,
        0,
        1,
        0,
      ]),
      child: image,
    );
  }

  @override
  void dispose() {
    for (final burst in _bursts) {
      burst.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_bursts.isEmpty) return const SizedBox.expand();
    final still = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        final diameter = math.min(box.maxWidth, box.maxHeight);
        final center = Offset(box.maxWidth / 2, box.maxHeight / 2);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final burst in _bursts)
              AnimatedBuilder(
                animation: burst.controller,
                builder: (context, _) {
                  final v = burst.controller.value;
                  final trailWidth = diameter / 3 * burst.trailScale;
                  final trailHeight = trailWidth / _aspect;
                  final outward = Offset(
                    math.cos(burst.angle),
                    math.sin(burst.angle),
                  );
                  final origin = center + outward * (diameter / 2 * .97);
                  final trailT = Curves.easeOut.transform(
                    (v / _trailShare).clamp(0.0, 1.0),
                  );
                  final trailAt =
                      origin + outward * (still ? 0 : _trailTravel * trailT);
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // 薄い粉の軌跡。粉の集まる側を縁に、散る側を外へ向ける。
                      Positioned(
                        left: trailAt.dx - _anchor.dx * trailWidth,
                        top: trailAt.dy - _anchor.dy * trailHeight,
                        width: trailWidth,
                        height: trailHeight,
                        child: Opacity(
                          opacity: _trailOpacity * (1 - trailT),
                          child: Transform.rotate(
                            angle: burst.angle - _imageDirection,
                            alignment: Alignment(
                              _anchor.dx * 2 - 1,
                              _anchor.dy * 2 - 1,
                            ),
                            child: _tinted(
                              const Image(image: _trail, fit: BoxFit.fill),
                            ),
                          ),
                        ),
                      ),
                      // はがれて飛び散る破片。
                      for (final flake in burst.flakes)
                        Builder(
                          builder: (context) {
                            final t = Curves.easeOutCubic.transform(v);
                            final angle = burst.angle + flake.spread;
                            final size = diameter * flake.size;
                            final at = still
                                ? origin
                                : origin +
                                      Offset(math.cos(angle), math.sin(angle)) *
                                          (flake.distance * t) +
                                      Offset(0, flake.fall * v * v);
                            return Positioned(
                              left: at.dx - size / 2,
                              top: at.dy - size / 2,
                              width: size,
                              height: size,
                              child: Opacity(
                                opacity: (1 - Curves.easeIn.transform(v)).clamp(
                                  0.0,
                                  1.0,
                                ),
                                child: Transform.rotate(
                                  angle: still ? 0 : flake.spin * v,
                                  child: _tinted(
                                    Image(
                                      image: flake.image,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _RoundHeader extends StatelessWidget {
  const _RoundHeader({required this.game});
  final GameController game;

  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 12,
    runSpacing: 5,
    children: [
      Text(
        game.phase == GamePhase.result ? '今回の仕上がり' : game.material!.name,
        style: const TextStyle(
          color: chalk,
          fontWeight: FontWeight.w700,
          fontSize: 17,
        ),
      ),
      if (game.phase != GamePhase.result)
        Text(
          '${game.round} 回目 / 全3回',
          style: const TextStyle(
            color: muted,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
    ],
  );
}

/// 四角いっぱいに広がる作業面。枠・段階名・研磨の割合は出さず、素材だけを大きく見せる。
class _Workpiece extends StatelessWidget {
  const _Workpiece({required this.game, required this.inContact});
  final GameController game;
  final bool inContact;
  @override
  Widget build(BuildContext context) {
    final material = game.material!;
    final image = _imageFor(material, game.progress);
    final art = SurfaceArt(
      material: material,
      progress: game.progress,
      strokeCount: game.totalStrokes,
      inContact: inContact,
      reveal: game.phase == GamePhase.result,
      medalImage: image == null
          ? null
          : _MedalImage(
              image,
              copperTint: image == _medalStageImages.first
                  ? material
                        .colorAt(game.progress)
                        .withValues(
                          alpha: .60 * (1 - material.rustAt(game.progress)),
                        )
                  : null,
            ),
    );
    return Semantics(
      image: true,
      excludeSemantics: true,
      label: _stageName(game),
      value: '研磨 ${(game.progress * 100).round()}%',
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          art,
          // メダルを磨いている間、1往復ごとに縁から削りかすを飛ばす。銀・金は段階の色に塗る。
          Positioned.fill(
            child: IgnorePointer(
              child: _Shavings(
                strokes: game.totalStrokes,
                active: game.phase == GamePhase.polishing && image != null,
                tint: image == null || image == _medalStageImages.first
                    ? null
                    : game.stage.color,
                grit: game.grit,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
