import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/design_tokens.dart';
import '../models/space_record.dart';
import 'record_detail.dart';

class RecordList extends StatelessWidget {
  const RecordList({super.key, required this.records, this.showDate = false});
  final List<SpaceRecord> records;
  final bool showDate;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final record in records)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: DesignTokens.surface.withValues(alpha: .8),
            borderRadius: BorderRadius.circular(18),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              leading: Icon(record.emotion.icon, color: record.emotion.color),
              title: Text(
                '${record.emotion.label} · ${record.category.label}',
                style: const TextStyle(fontSize: 14),
              ),
              subtitle: Text(
                '${DateFormat(showDate ? 'M月d日 HH:mm' : 'HH:mm', 'ja').format(record.createdAt.toLocal())}'
                '${record.note.isEmpty ? '' : '  ${record.note}'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: DesignTokens.muted, fontSize: 12),
              ),
              trailing: const Icon(
                Icons.chevron_right,
                size: 18,
                color: DesignTokens.muted,
              ),
              onTap: () => showRecordDetail(context, record),
            ),
          ),
        ),
    ],
  );
}
