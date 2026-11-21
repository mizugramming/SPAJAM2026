import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/game.dart';
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

class Workshop extends StatelessWidget {
  const Workshop({
    super.key,
    required this.game,
    required this.actions,
    required this.simulated,
    required this.busy,
    required this.error,
    required this.voiceMode,
  });

  final GameController game;
  final WorkshopActions actions;
  final bool simulated;
  final bool busy;
  final String? error;
  final VoiceMode voiceMode;

  @override
  Widget build(BuildContext context) {
    final selecting = game.phase == GamePhase.select;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: LayoutBuilder(
              builder: (context, layout) {
                final padding = layout.maxWidth < 360 ? 16.0 : 22.0;
                return ListView(
                  key: ValueKey((game.phase, game.round)),
                  padding: EdgeInsets.fromLTRB(padding, 10, padding, 24),
                  children: [
                    _Header(
                      onDiagnostics: selecting ? actions.openDiagnostics : null,
                      simulated: simulated,
                    ),
                    SizedBox(height: selecting ? 22 : 12),
                    if (selecting) ...[
                      const _Title('磨く素材を選ぶ'),
                      const SizedBox(height: 8),
                      const _Body('声でやすりを選び、スマホを動かして磨きます。'),
                      const SizedBox(height: 22),
                      for (final option in materials) ...[
                        _MaterialCard(
                          key: ValueKey('material-${option.id}'),
                          material: option,
                          onTap: () => actions.choose(option),
                        ),
                        const SizedBox(height: 13),
                      ],
                    ] else ...[
                      _RoundHeader(game: game),
                      const SizedBox(height: 12),
                      _Workpiece(
                        game: game,
                        height: (layout.maxHeight * .32).clamp(164.0, 290.0),
                      ),
                      const SizedBox(height: 20),
                      ..._controls(context),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _controls(BuildContext context) {
    final errorText = error;
    final errorPanel = <Widget>[
      if (errorText != null && errorText.isNotEmpty) ...[
        Semantics(
          liveRegion: true,
          child: Text(
            errorText,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 15,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    ];
    switch (game.phase) {
      case GamePhase.select:
        return [];
      case GamePhase.voice:
        return [
          _Title(busy ? '声を聞いています' : '声でやすりを選ぶ'),
          const SizedBox(height: 6),
          _Body(
            voiceMode == VoiceMode.pitch
                ? '低い声なら粗目、高い声なら細目。ひと息「あー」と声を出してください。'
                : '小さな声なら粗目、大きな声なら細目。ひと息「あー」と声を出してください。',
          ),
          if (simulated) ...[
            const SizedBox(height: 14),
            Wrap(
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
                      voiceMode == VoiceMode.pitch ? choice.$2 : choice.$3,
                    ),
                    selected: actions.demoPitch == choice.$1,
                    onSelected: busy
                        ? null
                        : (_) => actions.selectDemoPitch(choice.$1.toDouble()),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          ...errorPanel,
          PrimaryAction(
            key: const ValueKey('capture'),
            icon: Icons.mic_none_outlined,
            label: busy
                ? '採音中…'
                : simulated
                ? '疑似音声を使う'
                : '声を取る',
            onPressed: busy ? null : actions.capture,
          ),
          Align(
            alignment: Alignment.center,
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
        ];
      case GamePhase.ready:
        final measurement = game.sample;
        final measured = voiceMode == VoiceMode.pitch && measurement?.hz != null
            ? '${measurement!.hz!.round()} Hz'
            : '音量 ${((measurement?.level ?? 0) * 100).round()}%';
        return [
          _Title('${game.grit!.label}のやすり'),
          const SizedBox(height: 7),
          _Body('$measured の声で選ばれました。スマホを持ち、前後に動かす準備をしてください。'),
          const SizedBox(height: 18),
          ...errorPanel,
          PrimaryAction(
            key: const ValueKey('start'),
            icon: Icons.play_arrow_rounded,
            label: busy ? '準備中…' : '10秒間、磨き始める',
            onPressed: busy ? null : actions.start,
          ),
        ];
      case GamePhase.polishing:
        return [
          const _Title('スマホを前後に動かす'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
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
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: game.remainingSeconds / 10,
            semanticsLabel: '残り時間',
            minHeight: 4,
            backgroundColor: seam,
            color: ember,
          ),
          const SizedBox(height: 14),
          ...errorPanel,
          if (simulated)
            PrimaryAction(
              key: const ValueKey('simulate-stroke'),
              icon: Icons.swap_vert,
              label: '1往復を入力',
              onPressed: actions.simulateStroke,
            ),
        ];
      case GamePhase.result:
        return [
          _Title(game.stage.name),
          const SizedBox(height: 8),
          _Body('3回の研磨で、合計${game.totalStrokes}往復しました。'),
          if (game.verdict != null) ...[
            const SizedBox(height: 8),
            _Body(game.verdict!),
          ],
          const SizedBox(height: 18),
          PrimaryAction(
            key: const ValueKey('retry'),
            icon: Icons.replay_rounded,
            label: 'もう一度遊ぶ',
            onPressed: actions.retry,
          ),
        ];
    }
  }
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
    final p = Paint()..color = ember;
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
          child: LayoutBuilder(
            builder: (context, box) {
              final artWidth = (box.maxWidth * .50).clamp(86.0, 212.0);
              return Ink(
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
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
                              material.description ?? material.stages.last.name,
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
                      SizedBox(
                        width: artWidth,
                        height: artWidth * 1.10,
                        child: ExcludeSemantics(
                          child: SurfaceArt(material: material, progress: 1),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
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

class _Workpiece extends StatelessWidget {
  const _Workpiece({required this.game, required this.height});
  final GameController game;
  final double height;
  @override
  Widget build(BuildContext context) {
    final stage = game.stage;
    final material = game.material!;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: seam),
        borderRadius: BorderRadius.circular(14),
        gradient: RadialGradient(
          center: const Alignment(-.25, -.5),
          radius: 1.5,
          colors: [
            Color.lerp(metalPanel, material.colorAt(game.progress), .16)!,
            metalPanel,
            const Color(0xFF1A2020),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: height,
            child: SurfaceArt(
              material: material,
              progress: game.progress,
              strokeCount: game.totalStrokes,
              reveal: game.phase == GamePhase.result,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: stage.color,
                        border: Border.all(color: chalk.withValues(alpha: .45)),
                      ),
                      child: const SizedBox.square(dimension: 10),
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        game.phase == GamePhase.result
                            ? material.name
                            : stage.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: chalk,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '研磨 ${(game.progress * 100).round()}%',
                  style: const TextStyle(color: muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
