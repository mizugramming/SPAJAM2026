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
    this.inContact = false,
    this.onEnter,
    this.onTitle,
  });

  final GameController game;
  final WorkshopActions actions;
  final bool simulated;
  final bool busy;
  final String? error;
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
    final stage = screen == Screen.select
        ? _SelectStage(
            key: ValueKey((game.phase, game.round)),
            header: Part(
              'header',
              'ロゴ行',
              _Header(
                onDiagnostics: actions.openDiagnostics,
                simulated: simulated,
              ),
            ),
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
              if (!hasPaper && simulated)
                const Part(
                  'header',
                  '疑似入力表示',
                  Align(
                    alignment: Alignment.centerRight,
                    child: _simulatedLabel,
                  ),
                ),
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
    transition: arriving
        ? (canvas, bounds, paper) =>
              _paperEntrance(canvas, bounds, paper, game.grit!, game.sample!)
        : null,
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
            'title',
            '見出し',
            Center(
              child: _Title(
                busy
                    ? '声を聞いています'
                    : game.finishingWithFine
                    ? '仕上げは高い声で'
                    : 'やすりを作る',
              ),
            ),
            align: Alignment.center,
          ),
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
                        (110, '低い'),
                        (190, '中間'),
                        (300, '高い'),
                      ])
                        ChoiceChip(
                          key: ValueKey('demo-${choice.$1}'),
                          label: Text(choice.$2),
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
            'マイクボタン',
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
        ];
      case GamePhase.ready:
        return [
          Part(
            'title',
            'やすりの目',
            Center(child: _Title('${game.grit!.label}のやすり')),
            transition: _afterPaperLands,
            align: Alignment.center,
          ),
          _paper(arriving: true),
          errorPart,
          Part(
            'action',
            '開始ボタン',
            _BoxButton(
              key: const ValueKey('start'),
              icon: Icons.play_arrow_rounded,
              label: busy ? '準備中…' : '磨く！',
              onPressed: busy ? null : actions.start,
            ),
            transition: _afterPaperLands,
            fill: true,
          ),
        ];
      case GamePhase.polishing:
        return [
          const Part('cue', '開始の合図', _PolishCue(), fill: true),
          Part(
            'timer',
            '残り時間',
            Text(
              '残り ${game.remainingSeconds} 秒',
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w800,
                color: ember,
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
            '疑似研磨ボタン',
            !simulated
                ? null
                : _BoxButton(
                    key: const ValueKey('simulate-stroke'),
                    icon: Icons.swap_vert,
                    label: 'こする',
                    onPressed: actions.simulateStroke,
                  ),
            fill: true,
          ),
        ];
      case GamePhase.result:
        return [
          Part('title', '見出し', _Title(game.stage.name)),
          if (game.verdict case final verdict?)
            Part('body', '仕上がりの判定', _Body(verdict)),
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

/// A single timeline carries the captured mic to the middle, reveals the paper,
/// and unlocks start at its landing. The game clock begins with that button.
class _PaperArrival extends StatelessWidget {
  const _PaperArrival({super.key, required this.child});
  final Widget child;
  static const duration = Duration(milliseconds: 1800);

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

Widget _paperEntrance(
  Size canvas,
  Rect bounds,
  Widget child,
  Grit grit,
  VoiceSample sample,
) => Builder(
  builder: (context) {
    final t = _ArrivalProgress.of(context);
    const enter = Interval(0, .18, curve: Curves.easeOutCubic);
    const reveal = Interval(.13, .23, curve: Curves.easeOut);
    const leave = Interval(.64, .78, curve: Curves.easeInCubic);
    const fall = Interval(.78, 1, curve: Cubic(.36, .06, .25, 1));
    final mic = layoutTuner.boxOf(Screen.voice, 'action').rectIn(canvas);
    final center = Offset(canvas.width / 2, canvas.height / 2);
    final distanceOffscreen =
        center.dy + math.max(mic.height, canvas.height * .27);
    final movingCenter = Offset.lerp(
      mic.center,
      center,
      enter.transform(t),
    )!.translate(0, -distanceOffscreen * leave.transform(t));
    final readoutOpacity = reveal.transform(t) * (1 - leave.transform(t));

    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        ExcludeSemantics(
          excluding: t < 1,
          child: Transform.translate(
            offset: Offset(0, -(bounds.bottom + 1) * (1 - fall.transform(t))),
            child: child,
          ),
        ),
        if (t < leave.end) ...[
          Positioned.fromRect(
            rect: (Offset.zero & canvas).shift(-bounds.topLeft),
            child: IgnorePointer(
              child: ColoredBox(
                color: bench.withValues(alpha: .74 * readoutOpacity),
              ),
            ),
          ),
          Positioned.fromRect(
            rect: Rect.fromCenter(
              center: movingCenter - bounds.topLeft,
              width: mic.width,
              height: mic.height,
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
          if (readoutOpacity > 0)
            Positioned(
              left: .06 * canvas.width - bounds.left,
              width: .88 * canvas.width,
              top:
                  movingCenter.dy +
                  math.min(76.0, mic.height) / 2 +
                  8 -
                  bounds.top,
              height: canvas.height * .145,
              child: Opacity(
                opacity: readoutOpacity,
                child: Semantics(
                  liveRegion: true,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          sandpaperStampFor(sample),
                          key: const ValueKey('voice-reading'),
                          style: const TextStyle(
                            fontFamily: appFont,
                            color: chalk,
                            fontWeight: FontWeight.w900,
                            fontSize: 42,
                            height: 1.12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${grit.label}のやすり',
                          style: const TextStyle(
                            color: ember,
                            fontWeight: FontWeight.w800,
                            fontSize: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  },
);

/// The banner crosses the material once. Input remains live beneath it.
class _PolishCue extends StatelessWidget {
  const _PolishCue();

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 630),
        builder: (context, t, banner) {
          if (t == 1) return const SizedBox.shrink();
          final enter = const Interval(
            0,
            .26,
            curve: Curves.easeOutCubic,
          ).transform(t);
          final leave = const Interval(
            .67,
            1,
            curve: Curves.easeInCubic,
          ).transform(t);
          return FractionalTranslation(
            translation: Offset(reduced ? 0 : enter - 1 + leave, 0),
            child: Opacity(opacity: reduced ? 1 : 1 - leave, child: banner!),
          );
        },
        child: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0x00751619),
                Color(0xF88E1D21),
                Color(0xFA701418),
                Color(0x00751619),
              ],
              stops: [0, .18, .82, 1],
            ),
          ),
          child: FittedBox(
            fit: BoxFit.contain,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '磨け',
                style: TextStyle(
                  color: chalk,
                  fontFamily: appFont,
                  fontSize: 72,
                  height: 1.05,
                  letterSpacing: 7,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
      alignment: Alignment.center,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.label,
        onTap: widget.onPressed,
        excludeSemantics: true,
        child: InkResponse(
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

const _simulatedLabel = Text(
  '疑似入力',
  style: TextStyle(fontSize: 12, color: muted),
);

class _Header extends StatelessWidget {
  const _Header({required this.onDiagnostics, required this.simulated});
  final VoidCallback onDiagnostics;
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
      if (simulated) _simulatedLabel,
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

/// game.dart の段階（サビた銅・銅・銀・金・金ピカ）と同じ順のメダル画像。
/// 銅の2段階は同じ絵にゲームの研磨率に応じた地金色・サビ・光沢を重ねる。
const _medalStageImages = [
  'assets/fonts/daou.jpg',
  'assets/fonts/daou.jpg',
  'assets/fonts/gin.jpg',
  'assets/fonts/kin.jpg',
  'assets/fonts/kinpika.jpg',
];

/// 素材と研磨の割合に合う画像。画像のない素材は null（描画で表示する）。
String? _imageFor(WorkMaterial material, double progress) {
  if (material.id != 'medal') return null;
  return _medalStageImages[material.stages.indexOf(material.stageAt(progress))];
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

class _Shavings extends StatefulWidget {
  const _Shavings({
    required this.strokes,
    required this.active,
    required this.inContact,
    required this.progress,
    this.tint,
    this.grit,
  });
  final int strokes;
  final bool active;
  final bool inContact;
  final double progress;

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
  List<({double offset, double spread, double travel, double size})> dust,
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
    -34.0,
    -144.0,
    22.0,
    -161.0,
    -54.0,
    -118.0,
    38.0,
    159.0,
  ];

  /// 粉の画像の中で粉が集まっている点（幅・高さに対する割合）と、破片が散る向き。
  static const _anchor = Offset(.25, .73);
  static final _imageDirection = math.atan2(-341, 512);
  static const _aspect = 512 / 341;
  static const _trailTravel = 40.0;
  static const _trailOpacity = .78;

  /// 全体の長さと、そのうち粉の軌跡が消えるまでの長さ。
  static const _duration = Duration(milliseconds: 420);
  static const _trailShare = 300 / 420;

  // A quick hand can complete several passes during one particle's lifetime.
  static const _maxBursts = 4;
  final _bursts = <_Burst>[];
  Timer? _contactDust;
  int _sequence = 0;
  int _pass = 0;
  bool _canAnimate = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _canAnimate =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    _syncContact();
  }

  @override
  void didUpdateWidget(_Shavings old) {
    super.didUpdateWidget(old);
    if (_canAnimate && widget.active) {
      final scored = widget.strokes > old.strokes;
      if (scored || (widget.inContact && !old.inContact)) {
        _pass++;
        _burst(chips: scored);
      }
    }
    _syncContact();
  }

  void _syncContact() {
    if (!_canAnimate || !widget.active) {
      for (final burst in _bursts) {
        burst.controller.dispose();
      }
      _bursts.clear();
    }
    if (_canAnimate && widget.active && widget.inContact) {
      // Contact comes from the motion detector. The fine spray bridges the
      // space between the push and the scored return, without advancing either.
      _contactDust ??= Timer.periodic(const Duration(milliseconds: 180), (_) {
        setState(() => _burst(chips: false));
      });
    } else {
      _contactDust?.cancel();
      _contactDust = null;
    }
  }

  void _burst({required bool chips}) {
    if (_bursts.length >= _maxBursts) {
      _bursts.removeAt(0).controller.dispose();
    }
    final sequence = _sequence++;
    final random = math.Random(sequence);
    final kind = _shavingsFor(widget.grit);
    final copperCount = (kind.count * .6).round();
    final controller = AnimationController(vsync: this, duration: _duration);
    final burst = (
      controller: controller,
      angle:
          (_angles[_pass % _angles.length] + random.nextDouble() * 10 - 5) *
          math.pi /
          180,
      trailScale: kind.trail,
      dust: [
        for (var i = 0; i < (chips ? 24 : 12) + kind.count; i++)
          (
            offset: random.nextDouble(),
            spread: (random.nextDouble() - .5) * 1.6,
            travel: (.07 + .24 * random.nextDouble()) * kind.reach,
            size: (.0028 + .0035 * random.nextDouble()) * kind.size,
          ),
      ],
      flakes: [
        for (var i = 0; chips && i < kind.count; i++)
          (
            image: i < copperCount
                ? _copper[random.nextInt(_copper.length)]
                : _teal[random.nextInt(_teal.length)],
            spread: (random.nextDouble() - .5) * 1.4,
            distance: (.09 + random.nextDouble() * .17) * kind.reach,
            spin: (random.nextBool() ? 1 : -1) * (4 + random.nextDouble() * 8),
            size: (.035 + random.nextDouble() * .03) * kind.size,
            fall: .04 + random.nextDouble() * .08,
          ),
      ],
    );
    _bursts.add(burst);
    controller.forward().whenComplete(() {
      if (!mounted || !_bursts.contains(burst)) return;
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
    _contactDust?.cancel();
    for (final burst in _bursts) {
      burst.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_bursts.isEmpty) return const SizedBox.expand();
    return LayoutBuilder(
      builder: (context, box) {
        final diameter = math.min(box.maxWidth, box.maxHeight);
        final center = Offset(box.maxWidth / 2, box.maxHeight * .48);
        return Stack(
          clipBehavior: Clip.hardEdge,
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
                  // Start on the face so the first grains are visible before
                  // they cross the rim, including on narrow phones.
                  final origin = center + outward * (diameter * .29);
                  final trailT = Curves.easeOut.transform(
                    (v / _trailShare).clamp(0.0, 1.0),
                  );
                  final trailAt = origin + outward * (_trailTravel * trailT);
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          key: const ValueKey('abrasive-dust'),
                          painter: _DustSpray(
                            burst,
                            v,
                            origin,
                            diameter,
                            widget.tint,
                            widget.progress,
                          ),
                        ),
                      ),
                      // 一往復が成立したら、細かいチリに画像の粉と破片を重ねる。
                      if (burst.flakes.isNotEmpty)
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
                            final at =
                                origin +
                                Offset(math.cos(angle), math.sin(angle)) *
                                    (diameter * flake.distance * t) +
                                Offset(0, diameter * flake.fall * v * v);
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
                                  angle: flake.spin * v,
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

/// A short sweep across the face breaks into a fan of mineral dust.
class _DustSpray extends CustomPainter {
  const _DustSpray(
    this.burst,
    this.t,
    this.origin,
    this.diameter,
    this.tint,
    this.progress,
  );
  final _Burst burst;
  final double t;
  final Offset origin;
  final double diameter;
  final Color? tint;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final base = tint ?? const Color(0xffbb704a);
    final highlight = Color.lerp(
      base,
      const Color(0xffffefcc),
      .56 + .27 * progress,
    )!;
    final dark = Color.lerp(base, const Color(0xff462919), .52)!;
    final fade = 1 - Curves.easeIn.transform(t);
    final advance = Curves.easeOut.transform(t);
    final grain = Paint()..strokeCap = StrokeCap.round;
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.rotate(burst.angle);

    // Parallel striations are visible only while the grit is passing.
    if (t < .54) {
      final x = diameter * advance * .17;
      grain.color = highlight.withValues(alpha: .68 * (1 - t / .54));
      grain.strokeWidth = diameter * .003;
      for (var j = 0; j < 3; j++) {
        final y = diameter * (j - 1) * .015;
        canvas.drawLine(
          Offset(x - diameter * (.14 - .024 * j), y),
          Offset(x, y),
          grain,
        );
      }
    }
    for (var i = 0; i < burst.dust.length; i++) {
      final dust = burst.dust[i];
      final travel = diameter * dust.travel * advance;
      final x =
          (dust.offset - .5) * diameter * .12 + math.cos(dust.spread) * travel;
      final y = math.sin(dust.spread) * (travel + diameter * .05);
      final radius = (dust.size * diameter * (1 - .28 * progress)).clamp(
        .7,
        3.2,
      );
      final color = switch (i % 3) {
        0 => dark,
        1 => base,
        _ => highlight,
      };
      grain.color = color.withValues(alpha: .95 * fade);
      grain.strokeWidth = radius * 1.5;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + radius * 1.7, y + radius * dust.spread),
        grain,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DustSpray old) =>
      old.burst != burst ||
      old.t != t ||
      old.origin != origin ||
      old.diameter != diameter ||
      old.tint != tint ||
      old.progress != progress;
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
      label: game.stage.name,
      value: '研磨 ${(game.progress * 100).round()}%',
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          art,
          // 接触中のチリと、往復が成立したときの大きな破片を重ねる。
          Positioned.fill(
            child: IgnorePointer(
              child: _Shavings(
                strokes: game.totalStrokes,
                active: game.phase == GamePhase.polishing,
                inContact: inContact,
                progress: game.progress,
                tint: image == _medalStageImages.first
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
