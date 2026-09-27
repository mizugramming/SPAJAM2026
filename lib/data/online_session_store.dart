import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class OnlineSession {
  const OnlineSession({
    required this.endpoint,
    required this.code,
    required this.participantId,
    required this.token,
  });
  final String endpoint, code, participantId, token;
  Map<String, Object> toJson() => {
    'endpoint': endpoint,
    'code': code,
    'participantId': participantId,
    'token': token,
  };
  factory OnlineSession.fromJson(Map<String, dynamic> value) => OnlineSession(
    endpoint: value['endpoint'] as String,
    code: value['code'] as String,
    participantId: value['participantId'] as String,
    token: value['token'] as String,
  );
}

/// A secret, durable retry ticket written before the first admission request.
/// Never put this value in a QR, URL, log, or participant snapshot.
class PendingAdmission {
  const PendingAdmission({
    required this.endpoint,
    required this.key,
    required this.kind,
    this.roomCode,
    this.presentation,
    this.durationSeconds,
  });
  final String endpoint, key, kind;
  final String? roomCode;
  final bool? presentation;
  final int? durationSeconds;

  Map<String, Object?> toJson() => {
    'endpoint': endpoint,
    'key': key,
    'kind': kind,
    'roomCode': roomCode,
    'presentation': presentation,
    'durationSeconds': durationSeconds,
  };

  factory PendingAdmission.fromJson(Map<String, dynamic> value) =>
      PendingAdmission(
        endpoint: value['endpoint'] as String,
        key: value['key'] as String,
        kind: value['kind'] as String,
        roomCode: value['roomCode'] as String?,
        presentation: value['presentation'] as bool?,
        durationSeconds: value['durationSeconds'] as int?,
      );

  bool matches(PendingAdmission other) =>
      endpoint == other.endpoint &&
      kind == other.kind &&
      roomCode == other.roomCode &&
      presentation == other.presentation &&
      durationSeconds == other.durationSeconds;
}

abstract interface class OnlineSessionStore {
  Future<OnlineSession?> load();
  Future<void> save(OnlineSession session);
  Future<void> clear();
  Future<PendingAdmission?> loadPending();
  Future<void> savePending(PendingAdmission pending);
  Future<void> clearPending();
}

class SecureOnlineSessionStore implements OnlineSessionStore {
  SecureOnlineSessionStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const _key = 'tsunagun.online.session.v1';
  static const _pendingKey = 'tsunagun.online.pending-admission.v1';
  @override
  Future<OnlineSession?> load() async {
    final value = await _storage.read(key: _key);
    if (value == null) return null;
    return OnlineSession.fromJson(
      Map<String, dynamic>.from(jsonDecode(value) as Map),
    );
  }

  @override
  Future<void> save(OnlineSession session) =>
      _storage.write(key: _key, value: jsonEncode(session.toJson()));
  @override
  Future<void> clear() => _storage.delete(key: _key);
  @override
  Future<PendingAdmission?> loadPending() async {
    final value = await _storage.read(key: _pendingKey);
    if (value == null) return null;
    return PendingAdmission.fromJson(
      Map<String, dynamic>.from(jsonDecode(value) as Map),
    );
  }

  @override
  Future<void> savePending(PendingAdmission pending) =>
      _storage.write(key: _pendingKey, value: jsonEncode(pending.toJson()));
  @override
  Future<void> clearPending() => _storage.delete(key: _pendingKey);
}

class MemoryOnlineSessionStore implements OnlineSessionStore {
  OnlineSession? value;
  PendingAdmission? pending;
  @override
  Future<OnlineSession?> load() async => value;
  @override
  Future<void> save(OnlineSession session) async {
    value = session;
  }

  @override
  Future<void> clear() async {
    value = null;
  }

  @override
  Future<PendingAdmission?> loadPending() async => pending;
  @override
  Future<void> savePending(PendingAdmission value) async {
    pending = value;
  }

  @override
  Future<void> clearPending() async {
    pending = null;
  }
}
