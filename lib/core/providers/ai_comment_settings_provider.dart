import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kEnabled = 'ai_comment_enabled';
const _kApiKey = 'ai_comment_openai_api_key';

class AiCommentSettings {
  const AiCommentSettings({this.enabled = false, this.apiKey = ''});
  final bool enabled;
  final String apiKey;

  bool get isConfigured => enabled && apiKey.trim().isNotEmpty;

  AiCommentSettings copyWith({bool? enabled, String? apiKey}) =>
      AiCommentSettings(
        enabled: enabled ?? this.enabled,
        apiKey: apiKey ?? this.apiKey,
      );
}

final aiCommentSettingsProvider =
    AsyncNotifierProvider<AiCommentSettingsNotifier, AiCommentSettings>(
      AiCommentSettingsNotifier.new,
    );

// Opt-in AI commentary: disabled by default, since the app otherwise keeps
// every record on-device. Enabling it sends the day's records (and any note
// text) to OpenAI, so both the toggle and the key are explicit user actions.
class AiCommentSettingsNotifier extends AsyncNotifier<AiCommentSettings> {
  @override
  Future<AiCommentSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    return AiCommentSettings(
      enabled: prefs.getBool(_kEnabled) ?? false,
      apiKey: prefs.getString(_kApiKey) ?? '',
    );
  }

  Future<void> save({bool? enabled, String? apiKey}) async {
    final current = await future;
    final updated = current.copyWith(enabled: enabled, apiKey: apiKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, updated.enabled);
    await prefs.setString(_kApiKey, updated.apiKey);
    state = AsyncData(updated);
  }
}
