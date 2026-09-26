import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../domain/models.dart';
import '../domain/online_room.dart';
import 'online_session_store.dart';
import 'online_transport.dart';

/// A view of server-owned state. Never computes rewards or injects outcomes.
class OnlineController extends ChangeNotifier {
  OnlineController({
    this.serverUrl = const String.fromEnvironment('TSUNAGUN_SERVER_URL'),
    OnlineTransport? transport,
    OnlineSessionStore? store,
    bool autoTick = true,
  }) : _transport =
           transport ??
           (serverUrl.isEmpty ? null : HttpOnlineTransport(serverUrl)),
       _store = store ?? MemoryOnlineSessionStore() {
    _clock.start();
    if (autoTick) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _notify());
    }
  }

  final String serverUrl;
  final OnlineTransport? _transport;
  final OnlineSessionStore _store;
  final Stopwatch _clock = Stopwatch();
  final Random _random = Random.secure();
  Timer? _ticker, _reconnect, _heartbeat;
  OnlineSocket? _socket;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  OnlineSession? _session;
  PendingAdmission? _pendingAdmission;
  OnlineRoom? _room;
  bool _disposed = false, _foreground = true, _connecting = false;
  bool _connected = false, _busy = false, _restoring = false;
  String? _error;
  int _generation = 0, _retry = 0, _clockBase = 0, _clockAt = 0;
  int _lastPong = 0;
  final Map<String, int> _pings = {};
  final Map<String, Completer<bool>> _commands = {};

  bool get configured => _transport != null;
  bool get connected => _connected;
  bool get busy => _busy;
  bool get restoring => _restoring;
  String? get error => _error;
  OnlineRoom? get room => _room;
  List<Participant> get participants => _room?.participants ?? const [];
  Participant? get self {
    for (final participant in participants) {
      if (participant.id == _room?.selfId) return participant;
    }
    return null;
  }

  List<Follower> get followers => _room?.followers ?? const [];
  OnlineEncounter? get encounter => _room?.encounter;
  EncounterResult? get result => encounter?.result;
  FinalSnapshot? get finalSnapshot => _room?.finalSnapshot;
  bool get isHost => _room != null && _room!.hostId == _room!.selfId;
  int get serverNow => _clockBase + (_clock.elapsedMilliseconds - _clockAt);
  String? get roomQr => _room == null ? null : 'tsunagun:room:${_room!.code}';
  String? get pairQr =>
      _room == null ? null : 'tsunagun:pair:${_room!.code}:${_room!.pairCode}';
  Duration get remaining =>
      Duration(milliseconds: max(0, (_room?.endsAt ?? serverNow) - serverNow));

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void clearError() {
    _error = null;
    _notify();
  }

  String _id() => List.generate(
    16,
    (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  void _accept(dynamic raw, {int? sentAt}) {
    if (_disposed || raw is! Map) return;
    final value = OnlineRoom.fromJson(Map<String, dynamic>.from(raw));
    if (value.selfId != _session?.participantId ||
        value.code != _session?.code) {
      return;
    }
    if (_room != null && value.revision < _room!.revision) return;
    _room = value;
    if (_clockBase == 0 || sentAt != null) {
      _clockBase =
          value.serverTime +
          (sentAt == null ? 0 : (_clock.elapsedMilliseconds - sentAt) ~/ 2);
      _clockAt = _clock.elapsedMilliseconds;
    }
    _notify();
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (_disposed || _busy || _restoring) return false;
    _busy = true;
    _error = null;
    _notify();
    try {
      if (!configured) {
        throw const OnlineFailure('接続先が未設定です。配布されたアプリの設定を確認してください。');
      }
      await action();
      return !_disposed;
    } catch (error) {
      if (!_disposed) {
        _error = error is FormatException
            ? error.message
            : error is OnlineFailure
            ? error.message
            : '処理を完了できませんでした。もう一度お試しください。';
      }
      return false;
    } finally {
      _busy = false;
      _notify();
    }
  }

  Future<void> restore() async {
    if (_disposed || _restoring || _session != null) return;
    _restoring = true;
    _notify();
    try {
      final session = await _store.load();
      if (_disposed || !configured) return;
      if (session == null || session.endpoint != serverUrl) {
        final pending = await _store.loadPending();
        if (_disposed || pending == null || pending.endpoint != serverUrl) {
          return;
        }
        _validateAdmission(pending);
        _pendingAdmission = pending;
        try {
          await _submitAdmission(pending);
        } on OnlineFailure catch (error) {
          _error = error.message;
        }
        return;
      }
      OnlineCodes.room(session.code);
      if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(session.token)) {
        throw const FormatException();
      }
      _session = session;
      try {
        final sentAt = _clock.elapsedMilliseconds;
        final value = await _transport!.request(
          'GET',
          '/rooms/${session.code}',
          token: session.token,
        );
        _accept(value['snapshot'], sentAt: sentAt);
      } on OnlineFailure catch (error) {
        if ([401, 404, 410].contains(error.status)) {
          await _store.clear();
          _session = null;
          _room = null;
          _error = '前のルームは終了しました。新しいルームに参加してください。';
          return;
        }
        _error = '前のルームへの接続を待っています。';
      }
      if (!_disposed) unawaited(_connect());
    } catch (_) {
      _error = '前の参加情報を読み込めませんでした。もう一度参加してください。';
    } finally {
      _restoring = false;
      _notify();
    }
  }

  Future<void> _startSession(Map<String, dynamic> value) async {
    final session = OnlineSession(
      endpoint: serverUrl,
      code: value['code'] as String,
      participantId: value['participantId'] as String,
      token: value['token'] as String,
    );
    if (_disposed) return;
    _session = session;
    _room = null;
    _clockBase = 0;
    _accept(value['snapshot']);
    try {
      await _store.save(session);
      await _store.clearPending();
      _pendingAdmission = null;
    } catch (_) {
      _error = '参加情報を端末に保存できませんでした。アプリを閉じずにご利用ください。';
    }
    if (!_disposed) unawaited(_connect());
  }

  void _validateAdmission(PendingAdmission pending) {
    if (pending.endpoint != serverUrl ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(pending.key) ||
        !['create', 'join'].contains(pending.kind)) {
      throw const FormatException('参加処理の保存情報を確認できません。');
    }
    if (pending.kind == 'join') {
      OnlineCodes.room(pending.roomCode ?? '');
      if (pending.presentation != null || pending.durationSeconds != null) {
        throw const FormatException('参加処理の保存情報を確認できません。');
      }
    } else if (pending.roomCode != null ||
        pending.presentation == null ||
        pending.durationSeconds == null ||
        pending.durationSeconds! < 60 ||
        pending.durationSeconds! > 3600) {
      throw const FormatException('ルーム作成の保存情報を確認できません。');
    }
  }

  Future<void> _admit(PendingAdmission requested) async {
    if (_session != null) throw const OnlineFailure('参加中のルームへ戻ってください。');
    final saved = _pendingAdmission ?? await _store.loadPending();
    final pending = saved != null && saved.matches(requested)
        ? saved
        : requested;
    _validateAdmission(pending);
    // Do not contact the server until the retry ticket is durable. Losing this
    // response must never consume a guest slot that this device cannot recover.
    try {
      await _store.savePending(pending);
    } catch (_) {
      throw const OnlineFailure('参加情報を端末に保存できませんでした。再度お試しください。');
    }
    _pendingAdmission = pending;
    await _submitAdmission(pending);
  }

  Future<void> _submitAdmission(PendingAdmission pending) async {
    if (_disposed) return;
    final value = await _transport!.request(
      'POST',
      pending.kind == 'create' ? '/rooms' : '/rooms/${pending.roomCode}/join',
      body: {
        'admissionKey': pending.key,
        if (pending.kind == 'create') ...{
          'mode': pending.presentation! ? 'presentation' : 'standard',
          'durationSeconds': pending.durationSeconds!,
        },
      },
    );
    if (pending.kind == 'join' && value['code'] != pending.roomCode) {
      throw const OnlineFailure('参加先を確認できませんでした。もう一度お試しください。');
    }
    await _startSession(value);
  }

  Future<bool> createRoom({
    required bool presentation,
    required Duration duration,
  }) => _run(
    () => _admit(
      PendingAdmission(
        endpoint: serverUrl,
        key: _id() + _id(),
        kind: 'create',
        presentation: presentation,
        durationSeconds: duration.inSeconds,
      ),
    ),
  );

  Future<bool> joinRoom(String codeOrQr) => _run(
    () => _admit(
      PendingAdmission(
        endpoint: serverUrl,
        key: _id() + _id(),
        kind: 'join',
        roomCode: OnlineCodes.room(codeOrQr),
      ),
    ),
  );

  Future<bool> _action(
    String type, [
    Map<String, Object?> payload = const {},
  ]) => _run(() async {
    final session = _session;
    if (session == null || !_connected) {
      throw const OnlineFailure('接続を待っています。つながってからお試しください。');
    }
    final value = await _transport!.request(
      'POST',
      '/rooms/${session.code}/actions',
      token: session.token,
      body: {'requestId': _id(), 'type': type, ...payload},
    );
    if (_session == session) _accept(value['snapshot']);
  });

  Future<bool> saveProfile(Profile profile) =>
      _action('profile', {'profile': profileToJson(profile)});
  Future<bool> startRoom() => _action('start');
  Future<bool> pair(String codeOrQr) async {
    try {
      return await _action('pair', {
        'peerCode': OnlineCodes.pair(codeOrQr, _room?.code ?? ''),
      });
    } on FormatException catch (error) {
      _error = error.message;
      _notify();
      return false;
    }
  }

  Future<bool> readyGame() => _action('ready', {
    'encounterId': encounter?.id,
    'round': encounter?.round,
  });
  Future<bool> cancelGame() =>
      _action('cancel', {'encounterId': encounter?.id});
  Future<bool> returnHome() =>
      _action('return', {'encounterId': encounter?.id});
  Future<bool> finishRoom() => _action('finish');
  Future<bool> startFinale() => _action('finale');

  Future<bool> sendGameInput(String type, Map<String, Object?> payload) async {
    if (_disposed || !_connected || !_foreground || _socket == null) {
      return false;
    }
    final id = _id();
    final pending = Completer<bool>();
    _commands[id] = pending;
    try {
      _socket!.send({
        'type': 'command',
        'requestId': id,
        'action': {'type': type, ...payload},
      });
      return await pending.future.timeout(const Duration(seconds: 5));
    } catch (_) {
      _error = '操作の確認を待っています。接続後に結果を確認します。';
      _notify();
      return false;
    } finally {
      _commands.remove(id);
    }
  }

  Future<void> _connect() async {
    if (_disposed ||
        !_foreground ||
        _connecting ||
        _connected ||
        _session == null) {
      return;
    }
    _reconnect?.cancel();
    _connecting = true;
    final generation = ++_generation;
    final session = _session!;
    try {
      if (_retry >= 2) {
        final valid = await _probeReconnectSession(session, generation);
        if (!valid || _disposed || !_foreground || generation != _generation) {
          return;
        }
      }
      final socket = await _transport!.connect(session.code);
      if (_disposed || !_foreground || generation != _generation) {
        await socket.close();
        return;
      }
      _socket = socket;
      _subscription = socket.messages.listen(
        (message) {
          if (_disposed || generation != _generation) return;
          try {
            switch (message['type']) {
              case 'snapshot':
                _accept(message['snapshot']);
                if (_room == null) throw const FormatException();
                _connected = true;
                _retry = 0;
                _lastPong = _clock.elapsedMilliseconds;
                _notify();
              case 'ack':
                _accept(message['snapshot']);
                final request = _commands[message['requestId']];
                if (request != null && !request.isCompleted) {
                  request.complete(true);
                }
              case 'error':
                _error = message['error'] as String? ?? '操作を受け付けられませんでした。';
                final request = _commands[message['requestId']];
                if (request != null && !request.isCompleted) {
                  request.complete(false);
                }
                _notify();
              case 'pong':
                final sent = _pings.remove(message['id']);
                if (sent != null) {
                  final elapsed = _clock.elapsedMilliseconds;
                  final rtt = elapsed - sent;
                  _lastPong = elapsed;
                  if (rtt < 1000) {
                    _clockBase =
                        (message['serverNow'] as num).toInt() + rtt ~/ 2;
                    _clockAt = elapsed;
                  }
                }
            }
          } catch (_) {
            _lost(generation);
          }
        },
        onError: (Object _) => _lost(generation),
        onDone: () => _lost(generation),
      );
      socket.send({'type': 'auth', 'token': session.token});
      if (_disposed || generation != _generation || _socket != socket) return;
      _lastPong = _clock.elapsedMilliseconds;
      _heartbeat?.cancel();
      _heartbeat = Timer.periodic(const Duration(seconds: 3), (_) {
        if (_disposed || generation != _generation) return;
        if (_clock.elapsedMilliseconds - _lastPong > 12000) {
          _lost(generation);
          return;
        }
        _ping();
      });
      _ping();
    } catch (_) {
      if (generation == _generation) _lost(generation);
    } finally {
      if (generation == _generation) _connecting = false;
    }
  }

  /// Upgrade/auth failures cannot provide an HTTP status reliably on Web.
  /// After repeated failures, an authenticated GET distinguishes a temporary
  /// outage from an expired/deleted/revoked session instead of looping forever.
  Future<bool> _probeReconnectSession(
    OnlineSession session,
    int generation,
  ) async {
    try {
      final sentAt = _clock.elapsedMilliseconds;
      final value = await _transport!.request(
        'GET',
        '/rooms/${session.code}',
        token: session.token,
      );
      if (_disposed || generation != _generation || _session != session) {
        return false;
      }
      _accept(value['snapshot'], sentAt: sentAt);
      return true;
    } on OnlineFailure catch (error) {
      if (_disposed || generation != _generation || _session != session) {
        return false;
      }
      if (![401, 404, 410].contains(error.status)) return true;
      _restoring = true;
      _reconnect?.cancel();
      _dropSocket();
      _session = null;
      _pendingAdmission = null;
      _room = null;
      _clockBase = 0;
      _error = '前のルームは終了しました。新しいルームに参加してください。';
      _notify();
      try {
        await _store.clear();
        await _store.clearPending();
      } catch (_) {
        _error = '前のルームは終了しました。端末の参加情報を削除できなかったため、再起動時に再確認します。';
      } finally {
        _restoring = false;
        _notify();
      }
      return false;
    } catch (_) {
      return !_disposed && generation == _generation && _session == session;
    }
  }

  void _ping() {
    final id = _id();
    _pings[id] = _clock.elapsedMilliseconds;
    try {
      _socket?.send({'type': 'ping', 'id': id});
    } catch (_) {
      _lost(_generation);
    }
  }

  void _lost(int generation) {
    if (_disposed || generation != _generation) return;
    _dropSocket();
    _notify();
    if (!_foreground || _session == null) return;
    _retry++;
    _reconnect = Timer(Duration(seconds: min(8, _retry)), _connect);
  }

  void _dropSocket() {
    _generation++;
    _connected = false;
    _connecting = false;
    _heartbeat?.cancel();
    _pings.clear();
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) unawaited(subscription.cancel());
    final socket = _socket;
    _socket = null;
    if (socket != null) unawaited(socket.close().catchError((Object _) {}));
    for (final request in _commands.values) {
      if (!request.isCompleted) request.complete(false);
    }
    _commands.clear();
  }

  void setForeground(bool foreground) {
    if (_disposed || _foreground == foreground) return;
    _foreground = foreground;
    if (!foreground) {
      _reconnect?.cancel();
      _dropSocket();
      _notify();
    } else {
      unawaited(_connect());
    }
  }

  Future<bool> forgetSession() => _run(() async {
    await _store.clear();
    await _store.clearPending();
    _pendingAdmission = null;
    _reconnect?.cancel();
    _dropSocket();
    _session = null;
    _room = null;
    _clockBase = 0;
  });

  @override
  void dispose() {
    _disposed = true;
    _reconnect?.cancel();
    _ticker?.cancel();
    _dropSocket();
    _transport?.dispose();
    _clock.stop();
    super.dispose();
  }
}
