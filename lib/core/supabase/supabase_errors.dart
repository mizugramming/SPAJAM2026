import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/match_errors.dart';

/// サーバーの失敗を MatchException に変換する。
/// 接続仕様（docs/system_design.md）の `MQ:` コード以外は通信失敗として扱う。
MatchException toMatchException(Object error) {
  if (error is MatchException) return error;
  final code = _mqCode(error);
  if (code != null) return _fromCode(code);
  if (error is FunctionException && error.status == 503) {
    return const NetworkFailure('AI判定に接続できませんでした');
  }
  final denied = switch (error) {
    // 42501: RLS・権限で拒否された。
    PostgrestException(:final code) => code == '42501',
    StorageException(:final statusCode) => statusCode == '401' || statusCode == '403',
    _ => false,
  };
  if (denied) return const PermissionDenied();
  // 接続できない（SocketException・タイムアウト等）も、仕様外の応答も再試行できる通信失敗として扱う。
  return const NetworkFailure();
}

/// 失敗を MatchException に変換して投げ直す。
Future<T> guard<T>(Future<T> Function() action) async {
  try {
    return await action();
  } catch (e) {
    throw toMatchException(e);
  }
}

String? _mqCode(Object error) {
  final text = switch (error) {
    PostgrestException(:final message) => message,
    FunctionException(:final details) => details is Map ? '${details['error']}' : '$details',
    _ => null,
  };
  if (text == null) return null;
  final match = RegExp(r'MQ:(\w+)').firstMatch(text);
  return match?.group(1);
}

MatchException _fromCode(String code) {
  switch (code) {
    case 'permission':
      return const PermissionDenied();
    case 'notFound':
      return const NotFound();
  }
  final rule = MatchRule.values.asNameMap()[code];
  // 知らないコードは仕様の食い違い。通信失敗と区別できるよう権限エラー扱いにはしない。
  return rule != null ? MatchRuleViolation(rule) : NotFound('不明なエラー（$code）');
}
