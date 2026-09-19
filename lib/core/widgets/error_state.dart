import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/space_records_provider.dart';

class ErrorState extends ConsumerWidget {
  const ErrorState({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('記録を読み込めませんでした。', textAlign: TextAlign.center),
        const SizedBox(height: 8),
        const Text('保存済みのデータは変更していません。', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () {
            ref.invalidate(spaceRepositoryProvider);
            ref.invalidate(spaceRecordsProvider);
          },
          child: const Text('もう一度読み込む'),
        ),
      ],
    ),
  );
}
