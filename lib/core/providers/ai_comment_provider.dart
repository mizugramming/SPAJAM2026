import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_comment_service.dart';
import '../utils/constellation_name.dart';
import '../utils/date_key.dart';
import '../utils/record_queries.dart';
import 'ai_comment_settings_provider.dart';
import 'space_records_provider.dart';

const _kCachePrefix = 'ai_comment_cache_';

/// The AI-generated comment for a given day, or null when AI comments are
/// off, unconfigured, or the request failed — callers should fall back to
/// the app's own message in every one of those cases.
final aiCommentProvider = FutureProvider.family<String?, DateTime>((
  ref,
  day,
) async {
  final settings = await ref.watch(aiCommentSettingsProvider.future);
  if (!settings.isConfigured) return null;

  final records = await ref.watch(spaceRecordsProvider.future);
  final stars = recordsOnDay(records, day);
  if (stars.isEmpty) return null;

  final prefs = await SharedPreferences.getInstance();
  final cacheKey = '$_kCachePrefix${dateKey(day)}';
  final cached = prefs.getString(cacheKey);
  if (cached != null) return cached;

  final result = createConstellationResult(stars);
  final comment = await generateDailyComment(
    apiKey: settings.apiKey,
    records: stars,
    constellationName: result.name,
  );
  if (comment != null) {
    await prefs.setString(cacheKey, comment);
  }
  return comment;
});
