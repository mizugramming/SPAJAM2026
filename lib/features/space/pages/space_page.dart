import 'dart:async';
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
import '../widgets/planet_choice.dart';

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
  SpaceRecord? _savedRecord;
  @override
  void initState() {
    super.initState();
    _pauseTimer = Timer(const Duration(seconds: 30), () {
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

  void _backOrExit() {
    if (_form.saving) return;
    if (_form.step != SpaceStep.pause && _form.step != SpaceStep.complete) {
      _form.back();
    } else {
      _exit();
    }
  }

  Future<void> _exit() async {
    if (_form.saving || _confirming) return;
    if (_form.step == SpaceStep.complete) {
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
    setState(() => _savedRecord = record);
  }

  void _finish() {
    if (mounted && _savedRecord != null) {
      context.go(AppRoutes.constellationOn(_savedRecord!.createdAt));
    }
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

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _form,
    builder: (context, _) {
      final step = _form.step;
      return PopScope(
        canPop: _allowPop,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _backOrExit();
        },
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          body: SpaceBackground(
            scenic: step == SpaceStep.pause || step == SpaceStep.complete,
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
                        if (step != SpaceStep.pause &&
                            step != SpaceStep.complete)
                          IconButton(
                            tooltip: '前のステップへ',
                            onPressed: _form.saving ? null : _backOrExit,
                            icon: const Icon(Icons.arrow_back),
                          )
                        else
                          const SizedBox(width: 48),
                        Expanded(
                          child: Text(
                            step == SpaceStep.complete
                                ? 'A NEW STAR'
                                : 'S P A C E',
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
                    child: SingleChildScrollView(
                      key: ValueKey(step),
                      padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 480),
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
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontFamily: 'NotoSansJP',
                fontSize: title == 'ことばにしたくなったら。' ? 19 : 22,
                fontWeight: FontWeight.w300,
                letterSpacing: 2.2,
                height: 1.65,
                color: DesignTokens.ink.withValues(alpha: .94),
              ),
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
            const SizedBox(height: 72),
            _heading(context, '30秒だけ、ここに。', '今の自分に、少しだけ目を向けてみる。'),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: .82, end: 1),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(seconds: 2),
              builder: (_, scale, _) => Transform.scale(
                scale: scale,
                child: Container(
                  width: 124,
                  height: 124,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: DesignTokens.accent.withValues(alpha: .38),
                    ),
                    gradient: RadialGradient(
                      colors: [
                        DesignTokens.accent.withValues(alpha: .13),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.star_outline_rounded,
                    color: DesignTokens.gold,
                    size: 27,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 66),
            GlowButton(label: 'はじめる', onPressed: _next),
            const SizedBox(height: 14),
            TextButton(onPressed: _exit, child: const Text('今はやめておく')),
            const SizedBox(height: 8),
            const Text(
              '30秒待たずに、いつでもはじめられます。',
              style: TextStyle(fontSize: 11, color: DesignTokens.muted),
            ),
          ],
        );
      case SpaceStep.emotion:
        return Column(
          children: [
            const SizedBox(height: 26),
            _heading(context, '今に近いものを、ひとつ。', 'どの気持ちも、同じように星になります。'),
            for (final emotion in EmotionType.values)
              ChoiceTile(
                label: emotion.label,
                icon: emotion.icon,
                color: emotion.color,
                selected: _form.emotion == emotion,
                onTap: () => _form.selectEmotion(emotion),
              ),
            const SizedBox(height: 24),
            GlowButton(
              label: '次へ',
              onPressed: _form.emotion == null ? null : _next,
            ),
          ],
        );
      case SpaceStep.category:
        return Column(
          children: [
            const SizedBox(height: 26),
            _heading(context, 'この気持ちは、どこに近い？', '心に近い惑星を、ひとつ。'),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 8) / 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final category in CategoryType.values)
                      PlanetChoice(
                        width: width,
                        label: category.label,
                        icon: category.icon,
                        symbol: switch (category) {
                          CategoryType.relationships => PlanetSymbol.connection,
                          CategoryType.self => PlanetSymbol.innerCenter,
                          _ => PlanetSymbol.icon,
                        },
                        color: category.color,
                        selected: _form.category == category,
                        onTap: () => _form.selectCategory(category),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
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
            const SizedBox(height: 26),
            _heading(context, 'ことばにしたくなったら。', 'メモは残さなくても大丈夫です。'),
            TextField(
              controller: _note,
              onChanged: _form.setNote,
              enabled: !_form.saving,
              maxLength: 200,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              minLines: 6,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'メモ（任意）',
                hintText: '今、浮かんでいること',
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
            const SizedBox(height: 32),
            GlowButton(
              label: _note.text.trim().isEmpty ? '何も書かずに進む' : '確認へ進む',
              onPressed: _next,
            ),
          ],
        );
      case SpaceStep.review:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 26),
            _heading(context, 'この瞬間を、星に。', 'いま残すものを、そっと確かめる。'),
            _reviewItem(
              label: '気持ち',
              value: _form.emotion!.label,
              icon: _form.emotion!.icon,
              color: _form.emotion!.color,
            ),
            const SizedBox(height: 12),
            _reviewItem(
              label: 'テーマ',
              value: _form.category!.label,
              icon: _form.category!.icon,
              color: _form.category!.color,
            ),
            if (_form.note.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: DesignTokens.surface.withValues(alpha: .7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: DesignTokens.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ことば',
                      style: TextStyle(fontSize: 11, color: DesignTokens.muted),
                    ),
                    const SizedBox(height: 10),
                    Text(_form.note.trim()),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 28),
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
              label: '星にする',
              icon: Icons.star_rounded,
              busy: _form.saving,
              onPressed: _form.canSave ? _save : null,
            ),
            const SizedBox(height: 18),
            const Text(
              'この記録は、端末の中だけに保存されます。',
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
            const SizedBox(height: 30),
            _heading(
              context,
              _launched ? 'その星を、夜空へ。' : 'ひとつ、星が生まれました。',
              _launched ? '今日の星座に迎えてみましょう。' : '',
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 1700),
              curve: Curves.easeOutCubic,
              builder: (_, value, _) => AnimatedOpacity(
                opacity: _launching ? 0 : value.clamp(0.0, 1.0),
                duration: const Duration(milliseconds: 700),
                child: AnimatedSlide(
                  offset: _launching
                      ? const Offset(0, -2.4)
                      : Offset(0, _launchDragOffset / 230),
                  duration: const Duration(milliseconds: 700),
                  child: GestureDetector(
                    onVerticalDragUpdate: _onLaunchDragUpdate,
                    onVerticalDragEnd: _onLaunchDragEnd,
                    child: Transform.scale(
                      scale: .08 + .92 * value,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              DesignTokens.gold.withValues(
                                alpha: .35 + .2 * (1 - (value - .8).abs()),
                              ),
                              DesignTokens.accent.withValues(alpha: .1 * value),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Icon(
                          Icons.star_rounded,
                          color: DesignTokens.gold.withValues(
                            alpha: value < .55 ? .65 : 1,
                          ),
                          size: 24 + 46 * value,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
            if (_savedRecord != null)
              Text(
                '${DateFormat('HH:mm').format(_savedRecord!.createdAt.toLocal())} ・ '
                '${_savedRecord!.emotion.label} ・ ${_savedRecord!.category.label}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: DesignTokens.muted),
              ),
            const SizedBox(height: 28),
            if (!_launched && !_launching) ...[
              const Text(
                '↑ 星をスワイプして飛ばそう',
                style: TextStyle(fontSize: 11, color: DesignTokens.muted),
              ),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: _launch, child: const Text('星を飛ばす')),
              const SizedBox(height: 18),
            ],
            if (_launched) ...[
              GlowButton(
                label: createdToday ? '今日の星座は作成ずみです' : '今日の星座を作成する',
                icon: Icons.auto_awesome,
                onPressed: () => createTodayConstellationFlow(
                  context,
                  ref,
                  alreadyCreated: createdToday,
                ),
              ),
              const SizedBox(height: 14),
            ],
            GlowButton(label: '今日の星座を見る', onPressed: _finish),
            if (_launched) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go(AppRoutes.home),
                child: const Text('ホームへ戻る'),
              ),
            ],
          ],
        );
    }
  }

  Widget _reviewItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    decoration: BoxDecoration(
      color: DesignTokens.surface.withValues(alpha: .7),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: DesignTokens.border),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 26),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: DesignTokens.muted),
            ),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ],
    ),
  );
}
