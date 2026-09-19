import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../constants/design_tokens.dart';
import '../models/space_record.dart';
import '../providers/space_records_provider.dart';

Future<void> showRecordDetail(BuildContext context, SpaceRecord record) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _RecordDetail(record: record),
    );

class _RecordDetail extends ConsumerStatefulWidget {
  const _RecordDetail({required this.record});
  final SpaceRecord record;
  @override
  ConsumerState<_RecordDetail> createState() => _RecordDetailState();
}

class _RecordDetailState extends ConsumerState<_RecordDetail> {
  bool _deleting = false;
  String? _error;
  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('この星を削除しますか？'),
        content: const Text('この記録は元に戻せません。星座と惑星にも反映されます。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('残す'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除する'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ref
          .read(spaceRecordsProvider.notifier)
          .deleteById(widget.record.id);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _deleting = false;
          _error = '削除できませんでした。もう一度お試しください。';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    return PopScope(
      canPop: !_deleting,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          28,
          8,
          28,
          28 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat(
                  'yyyy年M月d日（E） HH:mm',
                  'ja',
                ).format(record.createdAt.toLocal()),
                style: const TextStyle(color: DesignTokens.muted),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Icon(
                    record.emotion.icon,
                    color: record.emotion.color,
                    size: 32,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      record.emotion.label,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Chip(
                avatar: Icon(record.category.icon, size: 16),
                label: Text(record.category.label),
              ),
              const SizedBox(height: 20),
              Text(
                record.note.isEmpty ? '言葉にしない余白。' : record.note,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 28),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, semanticsLabel: _error),
                ),
              TextButton.icon(
                onPressed: _deleting ? null : _delete,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: Text(_deleting ? '削除しています…' : 'この記録を削除'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
