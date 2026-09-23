import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/text_sentiment_service.dart';
import '../utils/record_queries.dart';
import 'ai_comment_settings_provider.dart';
import 'space_records_provider.dart';

const _kCachePrefix = 'text_sentiment_cache_';

/// Text-derived 1-5 mood score per record id, for every note-bearing record
/// in the given month. Records without a note are absent (nothing to
/// analyze). Null means AI comments are off/unconfigured, nothing has a
/// note this month, or the request failed.
///
/// Records can't be edited after creation, only added or deleted, so the
/// set of noted record ids fully identifies the month's content — that set
/// is the cache-invalidation key, avoiding a re-analysis (and its cost)
/// every time this month is viewed again.
final monthlyTextSentimentProvider =
    FutureProvider.family<Map<String, int>?, DateTime>((ref, month) async {
      final settings = await ref.watch(aiCommentSettingsProvider.future);
      if (!settings.isConfigured) return null;

      final all = await ref.watch(spaceRecordsProvider.future);
      final inMonth = recordsOnMonth(all, month);
      final noted = inMonth.where((r) => r.note.isNotEmpty).toList()
        ..sort((a, b) => a.id.compareTo(b.id));
      if (noted.isEmpty) return null;

      final prefs = await SharedPreferences.getInstance();
      final fingerprint = noted.map((r) => r.id).join(',');
      final cacheKey =
          '$_kCachePrefix${month.year}-${month.month.toString().padLeft(2, '0')}';
      final cachedFingerprint = prefs.getString('$cacheKey:fp');
      if (cachedFingerprint == fingerprint) {
        final cached = prefs.getStringList(cacheKey);
        if (cached != null) {
          return {
            for (final entry in cached)
              entry.split(':').first: int.parse(entry.split(':').last),
          };
        }
      }

      final scores = await analyzeMonthlyTextSentiment(
        apiKey: settings.apiKey,
        records: noted,
      );
      if (scores != null) {
        await prefs.setString('$cacheKey:fp', fingerprint);
        await prefs.setStringList(cacheKey, [
          for (final entry in scores.entries) '${entry.key}:${entry.value}',
        ]);
      }
      return scores;
    });

extension MonthlyTextSentimentSummary on Map<String, int> {
  double get average =>
      values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;
}
