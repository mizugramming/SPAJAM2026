import 'dart:async';
import 'dart:math' as math;

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
  });

  final GameController game;
  final WorkshopActions actions;
  final bool simulated;
  final bool busy;
  final String? error;
  final VoiceMode voiceMode;
  final bool inContact;
  final VoidCallback? onEnter;

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
    final stage = LayoutStage(
      key: ValueKey((game.phase, game.round)),
      screen: screen,
      background: _Background(subdued: hasPaper),
      parts: [
        if (!hasPaper)
          Part(
            'header',
            'ロゴ行',
            _Header(
              onDiagnostics: screen == Screen.select
                  ? actions.openDiagnostics
                  : null,
              simulated: simulated,
            ),
          ),
        if (screen == Screen.select)
          ..._selectParts(context)
        else ...[
          Part('round', 'ラウンド行', _RoundHeader(game: game)),
          Part(
            'workpiece',
            '素材',
            _Workpiece(game: game, inContact: inContact),
            fill: true,
          ),
          ..._controls(context),
        ],
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

  List<Part> _selectParts(BuildContext context) => [
    const Part('title', '見出し', _Title('磨く素材を選ぶ')),
    for (final option in materials)
      Part(
        'material-${option.id}',
        '${option.name}のカード',
        _MaterialCard(
          key: ValueKey('material-${option.id}'),
          material: option,
          onTap: () {
            unawaited(precacheImage(SandpaperFace.texture, context));
            actions.choose(option);
          },
        ),
        fill: true,
      ),
  ];

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
          Part('title', '見出し', _Title(busy ? '声を聞いています' : 'やすりを作る')),
          Part(
            'body',
            '声の出し方',
            _Body(simulated ? voiceHint : 'スマホを机に置いて「あー」とひと声。$voiceHint'),
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
            _BoxButton(
              key: const ValueKey('capture'),
              icon: Icons.mic_none_outlined,
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
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '残り ${game.remainingSeconds} 秒',
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: ember,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${game.grit!.label}   ·   ${game.strokes} 往復',
                    style: const TextStyle(color: chalk, fontSize: 16),
                  ),
                ],
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
          Part('title', '見出し', _Title(game.stage.name)),
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
              child: _BoxButton(
                key: ValueKey('voice-departure'),
                icon: Icons.mic_none_outlined,
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
    this.recorded = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool recorded;

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: Stack(
      fit: StackFit.expand,
      children: [
        FilledButton(
          style: FilledButton.styleFrom(
            disabledBackgroundColor: recorded ? crimson : null,
            disabledForegroundColor: recorded ? chalk : null,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(2)),
            ),
            textStyle: const TextStyle(
              fontFamily: 'WorkshopSans',
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
          child: CustomPaint(painter: _GrungePainter(label.hashCode)),
        ),
      ],
    ),
  );
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

/// 四角いっぱいに広がる素材カード。右に素材画、左に名前と説明。
class _MaterialCard extends StatelessWidget {
  const _MaterialCard({super.key, required this.material, required this.onTap});
  final WorkMaterial material;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = material.stages.last.color;
    return Semantics(
      button: true,
      label: material.name,
      child: Material(
        color: metalPanel,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: seam),
          borderRadius: BorderRadius.circular(14),
        ),
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
                colors: [
                  metalPanel,
                  Color.lerp(metalPanel, color, .055)!,
                  Color.lerp(metalPanel, color, .14)!,
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: LayoutBuilder(
                builder: (context, box) {
                  final artHeight = box.maxHeight;
                  final artWidth = math.min(box.maxWidth * .5, artHeight / 1.1);
                  final textWidth = math.max(0.0, box.maxWidth - artWidth - 8);
                  return Row(
                    children: [
                      SizedBox(
                        width: textWidth,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: textWidth,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ExcludeSemantics(
                                  child: Text(
                                    material.name,
                                    style: const TextStyle(
                                      color: chalk,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      height: 1.24,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 9),
                                Text(
                                  material.description ??
                                      material.stages.last.name,
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 13,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: ember,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: artWidth,
                        height: artHeight,
                        child: ExcludeSemantics(
                          child: switch (_imageFor(material, 0)) {
                            final String image => _MedalImage(
                              image,
                              cacheWidth: 480,
                            ),
                            _ => SurfaceArt(material: material, progress: 1),
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
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

/// 四角いっぱいに広がる作業面。下端に段階名と研磨の割合。
class _Workpiece extends StatelessWidget {
  const _Workpiece({required this.game, required this.inContact});
  final GameController game;
  final bool inContact;
  @override
  Widget build(BuildContext context) {
    final stage = game.stage;
    final material = game.material!;
    final image = _imageFor(material, game.progress);
    final surface = SurfaceArt(
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
    final atBench =
        game.phase == GamePhase.ready || game.phase == GamePhase.polishing;
    return DecoratedBox(
      decoration: atBench
          ? const BoxDecoration()
          : BoxDecoration(
              border: Border.all(color: seam),
              borderRadius: BorderRadius.circular(14),
              gradient: RadialGradient(
                center: const Alignment(-.25, -.5),
                radius: 1.5,
                colors: [
                  Color.lerp(metalPanel, material.colorAt(game.progress), .16)!,
                  metalPanel,
                  const Color(0xFF140F0F),
                ],
              ),
            ),
      child: LayoutBuilder(
        builder: (context, box) {
          final footer = math.min(36.0, box.maxHeight * .25);
          final footerWidth = math.max(0.0, box.maxWidth - 28);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: image == null || atBench
                      ? EdgeInsets.zero
                      : const EdgeInsets.all(10),
                  child: surface,
                ),
              ),
              SizedBox(
                height: footer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: footerWidth,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: stage.color,
                                    border: Border.all(
                                      color: chalk.withValues(alpha: .45),
                                    ),
                                  ),
                                  child: const SizedBox.square(dimension: 10),
                                ),
                                const SizedBox(width: 7),
                                Flexible(
                                  child: Text(
                                    game.phase == GamePhase.result
                                        ? material.name
                                        : stage.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: chalk,
                                      fontSize: atBench ? 18 : 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '研磨 ${(game.progress * 100).round()}%',
                            style: TextStyle(
                              color: atBench ? chalk : muted,
                              fontSize: atBench ? 17 : 13,
                              fontWeight: atBench ? FontWeight.w700 : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
