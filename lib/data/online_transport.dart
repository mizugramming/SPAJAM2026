import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

class OnlineFailure implements Exception {
  const OnlineFailure(this.message, {this.status = 0});
  final String message;
  final int status;
  @override
  String toString() => message;
}

abstract interface class OnlineSocket {
  Stream<Map<String, dynamic>> get messages;
  void send(Map<String, Object?> message);
  Future<void> close();
}

abstract interface class OnlineTransport {
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    String? token,
    Map<String, Object?>? body,
  });
  Future<OnlineSocket> connect(String code);
  void dispose();
}

class HttpOnlineTransport implements OnlineTransport {
  HttpOnlineTransport(
    String endpoint, {
    http.Client? client,
    @visibleForTesting this.requestTimeout = const Duration(seconds: 10),
  }) : _base = Uri.parse(endpoint),
       _client = client ?? http.Client() {
    if (!_base.hasAuthority ||
        _base.userInfo.isNotEmpty ||
        _base.hasQuery ||
        _base.hasFragment ||
        (_base.scheme != 'https' &&
            !(_base.scheme == 'http' &&
                (kDebugMode ||
                    const [
                      'localhost',
                      '127.0.0.1',
                      '::1',
                    ].contains(_base.host))))) {
      throw const FormatException('接続先にはHTTPSのサーバーを指定してください。');
    }
  }
  final Duration requestTimeout;
  final Uri _base;
  final http.Client _client;
  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    String? token,
    Map<String, Object?>? body,
  }) async {
    try {
      final abort = Completer<void>();
      final request = http.AbortableRequest(
        method,
        _base.resolve(path),
        abortTrigger: abort.future,
      );
      request.headers['Content-Type'] = 'application/json';
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      if (body != null) request.body = jsonEncode(body);
      final response =
          await (() async {
            final stream = await _client.send(request);
            return http.Response.fromStream(stream);
          })().timeout(
            requestTimeout,
            onTimeout: () {
              abort.complete();
              throw TimeoutException('HTTP request deadline');
            },
          );
      if (response.bodyBytes.length > 1024 * 1024) {
        throw const FormatException();
      }
      final value = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw OnlineFailure(
          value['error'] as String? ?? '接続できませんでした。もう一度お試しください。',
          status: response.statusCode,
        );
      }
      return value;
    } on OnlineFailure {
      rethrow;
    } on TimeoutException {
      throw const OnlineFailure('通信に時間がかかっています。接続を確認してください。');
    } catch (_) {
      throw const OnlineFailure('サーバーに接続できませんでした。通信環境を確認してください。');
    }
  }

  @override
  Future<OnlineSocket> connect(String code) async {
    final uri = _base
        .resolve('/rooms/$code/socket')
        .replace(scheme: _base.scheme == 'https' ? 'wss' : 'ws');
    final channel = WebSocketChannel.connect(uri);
    try {
      await channel.ready.timeout(const Duration(seconds: 8));
    } catch (_) {
      await channel.sink.close();
      rethrow;
    }
    return _ChannelSocket(channel);
  }

  @override
  void dispose() => _client.close();
}

class _ChannelSocket implements OnlineSocket {
  _ChannelSocket(this.channel);
  final WebSocketChannel channel;
  @override
  Stream<Map<String, dynamic>> get messages =>
      channel.stream.map((dynamic raw) {
        if (raw is! String || raw.length > 1024 * 1024) {
          throw const FormatException('Invalid message');
        }
        return Map<String, dynamic>.from(jsonDecode(raw) as Map);
      });
  @override
  void send(Map<String, Object?> message) =>
      channel.sink.add(jsonEncode(message));
  @override
  Future<void> close() async => channel.sink.close();
}
