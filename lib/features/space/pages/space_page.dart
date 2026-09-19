import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/design_tokens.dart';
import '../../../core/models/category_type.dart';
import '../../../core/models/emotion_type.dart';
import '../../../core/models/space_record.dart';
import '../../../core/providers/constellation_creation_provider.dart';
import '../../../core/providers/space_records_provider.dart';
import '../../../core/widgets/constellation_creation_flow.dart';
import '../../../core/widgets/page_frame.dart';
import '../../../core/widgets/space_background.dart';
import '../controllers/space_form_controller.dart';
import '../widgets/choice_tile.dart';

class SpacePage extends ConsumerStatefulWidget {
  const SpacePage({super.key});
  @override
  ConsumerState<SpacePage> createState() => _SpacePageState();
}

class _SpacePageState extends ConsumerState<SpacePage> {
  final _form = SpaceFormController();
  final _note = TextEditingController();
  Timer? _pauseTimer;
  bool _allowPop = false;
  bool _confirming = false;
  bool _launched = false;
  bool _launching = false;
  Timer? _launchAnimTimer;
  double _launchDragOffset = 0;
  SpaceRecord? _lastRecord;
  @override
  void initState() {
    super.initState();
    _pauseTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && _form.step == SpaceStep.pause) _form.next();
    });
  }

  @override
  void dispose() {
    _pauseTimer?.cancel();
    _launchAnimTimer?.cancel();
    _note.dispose();
    _form.dispose();
    super.dispose();
  }

  void _next() {
    _pauseTimer?.cancel();
    _form.next();
  }

  Future<void> _exit() async {
    if (_form.saving || _confirming) return;
    if (_form.isFinalStep) {
      _finish();
      return;
    }
    _confirming = true;
    final leave =
        !_form.hasInput ||
        await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('入力を閉じますか？'),
                content: const Text('選んだ気持ちとメモは保存されません。'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('続ける'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('閉じる'),
                  ),
                ],
              ),
            ) ==
            true;
    _confirming = false;
    if (leave && mounted) {
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(AppRoutes.home);
        }
      });
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final record = await _form.save(
      ref.read(spaceRecordsProvider.notifier).save,
    );
    if (record == null || !mounted) return;
    _note.clear();
    _lastRecord = record;
  }

  void _launch() {
    if (!mounted || _launched || _launching) return;
    setState(() => _launching = true);
    _launchAnimTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _launching = false;
        _launched = true;
      });
    });
  }

  void _onLaunchDragUpdate(DragUpdateDetails details) {
    if (_launching) return;
    setState(() {
      _launchDragOffset = (_launchDragOffset + details.delta.dy).clamp(
        -160.0,
        40.0,
      );
    });
  }

  void _onLaunchDragEnd(DragEndDetails details) {
    if (_launching) return;
    final flungUp =
        _launchDragOffset < -60 || (details.primaryVelocity ?? 0) < -600;
    setState(() => _launchDragOffset = 0);
    if (flungUp) _launch();
  }

  void _finish() {
    if (mounted) {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _form,
    builder: (context, _) {
      final step = _form.step;
      return PopScope(
        canPop:
            _allowPop ||
            (!_form.hasInput && !_form.saving && !_form.isFinalStep),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _exit();
        },
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          body: SpaceBackground(
            scenic: step == SpaceStep.pause || _form.isFinalStep,
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        if (step.index > 1 && !_form.isFinalStep)
                          IconButton(
                            tooltip: '前のステップへ',
                            onPressed: _form.saving ? null : _form.back,
                            icon: const Icon(Icons.arrow_back),
                          )
                        else
                          const SizedBox(width: 48),
                        Expanded(
                          child: Text(
                            step == SpaceStep.pause
                                ? 'S P A C E'
                                : step == SpaceStep.complete
                                ? (_launched ? 'INTO THE SKY' : 'A NEW STAR')
                                : '${step.index} / 3',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              letterSpacing: 3,
                              color: DesignTokens.muted,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: '閉じる',
                          onPressed: _form.saving ? null : _exit,
                          icon: const Icon(Icons.close, size: 22),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: step == SpaceStep.complete
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 480,
                                ),
                                child: _content(context),
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            key: ValueKey(step),
                            padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 480,
                                ),
                                child: _content(context),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
  Widget _heading(BuildContext context, String title, String subtitle) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: DesignTokens.muted),
            ),
          ],
        ),
      );
  Widget _content(BuildContext context) {
    switch (_form.step) {
      case SpaceStep.pause:
        return Column(
          children: [
            const SizedBox(height: 65),
            _heading(context, '少しだけ、\n何もしない。', '深呼吸して、\n今この瞬間を感じてみよう。'),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: .75, end: 1),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(seconds: 5),
              builder: (_, scale, _) => Transform.scale(
                scale: scale,
                child: Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: DesignTokens.accent.withValues(alpha: .45),
                    ),
                    gradient: RadialGradient(
                      colors: [
                        DesignTokens.accent.withValues(alpha: .16),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: DesignTokens.gold,
                    size: 28,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 56),
            OutlinedButton(onPressed: _next, child: const Text('スキップして気持ちを選ぶ')),
          ],
        );
      case SpaceStep.emotion:
        return Column(
          children: [
            _heading(context, 'いま、どんな感じ？', 'どんな気持ちも、あなたの星になる。'),
            for (final emotion in EmotionType.values)
              ChoiceTile(
                label: emotion.label,
                icon: emotion.icon,
                color: emotion.color,
                selected: _form.emotion == emotion,
                onTap: () => _form.selectEmotion(emotion),
              ),
            const SizedBox(height: 16),
            GlowButton(
              label: '次へ',
              onPressed: _form.emotion == null ? null : _next,
            ),
          ],
        );
      case SpaceStep.category:
        return Column(
          children: [
            _heading(context, '何についての気持ち？', 'いま、心に浮かんでいること。'),
            for (final category in CategoryType.values)
              ChoiceTile(
                label: category.label,
                hint: category.hint,
                icon: category.icon,
                color: category.color,
                selected: _form.category == category,
                onTap: () => _form.selectCategory(category),
              ),
            const SizedBox(height: 16),
            GlowButton(
              label: '次へ',
              onPressed: _form.category == null ? null : _next,
            ),
          ],
        );
      case SpaceStep.note:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _heading(context, '言葉を、ひとつ。', '書かなくても大丈夫。\n今の気持ちを、そのまま残そう。'),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                Chip(
                  avatar: Icon(
                    _form.emotion!.icon,
                    size: 16,
                    color: _form.emotion!.color,
                  ),
                  label: Text(_form.emotion!.label),
                ),
                Chip(
                  avatar: Icon(_form.category!.icon, size: 16),
                  label: Text(_form.category!.label),
                ),
              ],
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _note,
              onChanged: _form.setNote,
              enabled: !_form.saving,
              maxLength: 200,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              minLines: 5,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'メモ（任意）',
                hintText: 'いま浮かんでいること…',
                alignLabelWithHint: true,
              ),
              buildCounter:
                  (
                    _, {
                    required currentLength,
                    required isFocused,
                    maxLength,
                  }) => Text(
                    '残り ${200 - _note.text.characters.length} 文字',
                    style: const TextStyle(
                      fontSize: 11,
                      color: DesignTokens.muted,
                    ),
                  ),
            ),
            const SizedBox(height: 24),
            if (_form.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _form.error!,
                    style: const TextStyle(color: DesignTokens.gold),
                  ),
                ),
              ),
            GlowButton(
              label: '星を作る',
              icon: Icons.north,
              busy: _form.saving,
              onPressed: _form.canSave ? _save : null,
            ),
            const SizedBox(height: 20),
            const Text(
              'この気持ちは、端末の中だけに保存されます。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: DesignTokens.muted),
            ),
          ],
        );
      case SpaceStep.complete:
        final createdToday =
            ref
                .watch(constellationCreationProvider)
                .value
                ?.isCreated(DateTime.now()) ??
            false;
        return Column(
          children: [
            const SizedBox(height: 24),
            _heading(
              context,
              _launched ? 'その星を、\n夜空へ。' : 'あなたの言葉が、\n星になりました。',
              _launched ? 'そっと手を離して、\n星座の仲間に迎えよう。' : '立ち止まった時間も、あなたの一部。',
            ),
            Expanded(
              child: _launched
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_lastRecord != null) ...[
                            Text(
                              DateFormat(
                                'HH:mm',
                              ).format(_lastRecord!.createdAt.toLocal()),
                              style: const TextStyle(
                                fontSize: 13,
                                letterSpacing: 1,
                                color: DesignTokens.muted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              children: [
                                Chip(
                                  avatar: Icon(
                                    _lastRecord!.emotion.icon,
                                    size: 16,
                                    color: _lastRecord!.emotion.color,
                                  ),
                                  label: Text(_lastRecord!.emotion.label),
                                ),
                                Chip(
                                  avatar: Icon(
                                    _lastRecord!.category.icon,
                                    size: 16,
                                  ),
                                  label: Text(_lastRecord!.category.label),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _lastRecord!.note.isEmpty
                                  ? '（言葉はありません）'
                                  : _lastRecord!.note,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 36),
                          ],
                          GlowButton(
                            label: createdToday ? '今日の星座は作成ずみです' : '今日の星座を作成する',
                            icon: Icons.auto_awesome,
                            onPressed: () => createTodayConstellationFlow(
                              context,
                              ref,
                              alreadyCreated: createdToday,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: _finish,
                            child: const Text('ホームへ戻る'),
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          if (_launching)
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: MediaQuery.disableAnimationsOf(context)
                                  ? Duration.zero
                                  : const Duration(milliseconds: 700),
                              curve: Curves.easeOut,
                              builder: (_, burst, _) => CustomPaint(
                                size: const Size(320, 320),
                                painter: _SparkleBurstPainter(
                                  progress: burst,
                                  color: DesignTokens.gold,
                                ),
                              ),
                            ),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: .2, end: 1),
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 1800),
                            curve: Curves.easeOutCubic,
                            builder: (_, entrance, _) => AnimatedOpacity(
                              opacity: _launching ? 0 : entrance,
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeIn,
                              child: AnimatedScale(
                                scale: _launching ? .3 : entrance,
                                duration: const Duration(milliseconds: 700),
                                curve: Curves.easeIn,
                                child: AnimatedSlide(
                                  offset: _launching
                                      ? const Offset(0, -2.4)
                                      : Offset(0, _launchDragOffset / 230),
                                  duration: const Duration(milliseconds: 700),
                                  curve: Curves.easeIn,
                                  child: GestureDetector(
                                    onVerticalDragUpdate: _onLaunchDragUpdate,
                                    onVerticalDragEnd: _onLaunchDragEnd,
                                    child: Container(
                                      width: 230,
                                      height: 230,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            DesignTokens.gold.withValues(
                                              alpha: .55,
                                            ),
                                            DesignTokens.accent.withValues(
                                              alpha: .12,
                                            ),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.star_rounded,
                                        color: DesignTokens.gold,
                                        size: 84,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            if (!_launched && !_launching) ...[
              const SizedBox(height: 12),
              const Text(
                '↑ 星をスワイプして飛ばそう',
                style: TextStyle(fontSize: 11, color: DesignTokens.muted),
              ),
              const SizedBox(height: 24),
              OutlinedButton(onPressed: _launch, child: const Text('星を飛ばす')),
            ],
          ],
        );
    }
  }
}

class _SparkleBurstPainter extends CustomPainter {
  _SparkleBurstPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = size.center(Offset.zero);
    final random = math.Random(3);
    final maxRadius = size.shortestSide / 2;
    final fade = (1 - progress).clamp(0.0, 1.0);
    for (var i = 0; i < 14; i++) {
      final angle = (i / 14) * 2 * math.pi + random.nextDouble() * .3;
      final speed = .55 + random.nextDouble() * .45;
      final distance = maxRadius * progress * speed;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * distance;
      final radius = 1.4 + random.nextDouble() * 2.4;
      canvas.drawCircle(
        point,
        radius,
        Paint()
          ..color = (i.isEven ? color : Colors.white).withValues(
            alpha: fade * .9,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparkleBurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
