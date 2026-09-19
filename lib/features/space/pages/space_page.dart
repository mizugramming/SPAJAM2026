import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/design_tokens.dart';
import '../../../core/models/category_type.dart';
import '../../../core/models/emotion_type.dart';
import '../../../core/providers/space_records_provider.dart';
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
  Timer? _completeTimer;
  bool _allowPop = false;
  bool _confirming = false;
  DateTime? _savedAt;
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
    _completeTimer?.cancel();
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
    _savedAt = record.createdAt;
    _completeTimer = Timer(const Duration(milliseconds: 2600), _finish);
  }

  void _finish() {
    _completeTimer?.cancel();
    if (mounted) {
      context.go(AppRoutes.constellationOn(_savedAt ?? DateTime.now()));
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
            (!_form.hasInput && !_form.saving && step != SpaceStep.complete),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _exit();
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
                        if (step.index > 1 && step != SpaceStep.complete)
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
                                ? 'A NEW STAR'
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
              label: '宇宙へ放つ',
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
        return Column(
          children: [
            const SizedBox(height: 60),
            _heading(context, 'あなたの言葉が、\n星になりました。', '立ち止まった時間も、あなたの一部。'),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: .2, end: 1),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 1800),
              curve: Curves.easeOutCubic,
              builder: (_, value, _) => Opacity(
                opacity: value,
                child: Transform.scale(
                  scale: value,
                  child: Container(
                    width: 190,
                    height: 190,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          DesignTokens.gold.withValues(alpha: .55),
                          DesignTokens.accent.withValues(alpha: .12),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.star_rounded,
                      color: DesignTokens.gold,
                      size: 70,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
            OutlinedButton(onPressed: _finish, child: const Text('今日の星座へ')),
          ],
        );
    }
  }
}
