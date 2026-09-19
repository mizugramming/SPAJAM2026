import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_routes.dart';
import '../providers/constellation_creation_provider.dart';

Future<void> createTodayConstellationFlow(
  BuildContext context,
  WidgetRef ref, {
  required bool alreadyCreated,
}) async {
  if (alreadyCreated) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('今日はもう作成ずみです'),
        content: const Text('星座の作成は、一日一回までです。\nまた明日、つくりましょう。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('とじる'),
          ),
        ],
      ),
    );
    return;
  }
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('今日の星座を作成しますか？'),
      content: const Text('星座の作成は、一日一回までです。\nよろしいですか？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('戻る'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('作成する'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  final created = await ref
      .read(constellationCreationProvider.notifier)
      .createToday();
  if (!created || !context.mounted) return;
  context.push(AppRoutes.constellationRevealOn(DateTime.now()));
}
