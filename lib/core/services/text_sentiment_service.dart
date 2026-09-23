import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/space_record.dart';

const _endpoint = 'https://api.openai.com/v1/chat/completions';
const _model = 'gpt-4o-mini';

// Keeps a single journaler's month well within one request; if there are
// more notes than this, only the most recent ones are analyzed.
const _maxNotes = 60;

const _systemPrompt =
    '日本語の短い日記メモから、そのときの気分を5段階で判定します。'
    '5=うれしい, 4=穏やか, 3=ふつう, 2=疲れた, 1=つらい・不安。'
    '各メモにつき数値をひとつ、入力と同じ順番のJSON配列だけを返してください。'
    '説明・前置き・コードブロックなど、数値の配列以外は一切含めないでください。';

/// Batches every note-bearing record in a month into a single request and
/// asks for a compact 1-5 score per note, so cost stays at one short call
/// per month instead of one per record. Notes without text are skipped
/// entirely (nothing to analyze); if none have text, no call is made.
/// Returns record id -> score, or null on any failure/empty input.
Future<Map<String, int>?> analyzeMonthlyTextSentiment({
  required String apiKey,
  required List<SpaceRecord> records,
}) async {
  final noted = records.where((r) => r.note.isNotEmpty).toList();
  if (apiKey.trim().isEmpty || noted.isEmpty) return null;
  final sample = noted.length > _maxNotes
      ? noted.sublist(noted.length - _maxNotes)
      : noted;

  final lines = [
    for (var i = 0; i < sample.length; i++) '${i + 1}: ${sample[i].note}',
  ].join('\n');

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
              {'role': 'user', 'content': lines},
            ],
            // ~4 tokens per score is generous; caps worst-case cost/latency.
            'max_tokens': 20 + sample.length * 4,
            'temperature': 0,
          }),
        )
        .timeout(const Duration(seconds: 25));

    if (response.statusCode != 200) return null;
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    final choices = data['choices'] as List?;
    if (choices == null || choices.isEmpty) return null;
    final content = (choices.first as Map)['message']?['content'] as String?;
    if (content == null) return null;

    final scores = jsonDecode(content.trim()) as List;
    if (scores.length != sample.length) return null;

    return {
      for (var i = 0; i < sample.length; i++)
        sample[i].id: (scores[i] as num).round().clamp(1, 5),
    };
  } catch (_) {
    return null;
  }
}
