import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/space_record.dart';

const _endpoint = 'https://api.openai.com/v1/chat/completions';
const _model = 'gpt-4o-mini';

const _systemPrompt =
    '「余白」という感情記録アプリの語り手です。ユーザーが1日の中で残した感情の記録を読み、'
    'その日をやさしく振り返る、短いまとめコメントを日本語で返します。'
    'つらい・疲れたといった気持ちが含まれていても、否定的な言葉や批判めいた表現、'
    '心配をあおる言い方は使わないでください。どんな一日であっても、その日を過ごした'
    'こと自体を静かに肯定するトーンでまとめてください。'
    '説教や助言はせず、寄り添うトーンで、2文以内・80文字程度にまとめてください。';

/// Calls the OpenAI Chat Completions API to write a short reflection on the
/// day's records. Returns null on any failure (network, auth, parsing) so
/// callers can silently fall back to the app's built-in message.
Future<String?> generateDailyComment({
  required String apiKey,
  required List<SpaceRecord> records,
  required String constellationName,
}) async {
  if (apiKey.trim().isEmpty || records.isEmpty) return null;

  final lines = records
      .map((r) {
        final time =
            '${r.createdAt.hour.toString().padLeft(2, '0')}:'
            '${r.createdAt.minute.toString().padLeft(2, '0')}';
        final note = r.note.isEmpty ? '' : '「${r.note}」';
        return '$time ${r.emotion.label}・${r.category.label} $note';
      })
      .join('\n');

  final userPrompt =
      '今日生まれた星座:$constellationName\n'
      '今日の記録:\n$lines\n\n'
      'この1日を、否定的な言葉を使わずにまとめてください。';

  try {
    final response = await http
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': _model,
            'messages': [
              {'role': 'system', 'content': _systemPrompt},
              {'role': 'user', 'content': userPrompt},
            ],
            'max_tokens': 150,
            'temperature': 0.8,
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) return null;
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) return null;
    final content = (choices.first as Map)['message']?['content'] as String?;
    final trimmed = content?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  } catch (_) {
    return null;
  }
}
