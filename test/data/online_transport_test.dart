import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:spajam2026/data/online_transport.dart';

class _StalledClient extends http.BaseClient {
  _StalledClient({required this.headersArrive});
  final bool headersArrive;
  bool aborted = false;
  final headers = Completer<http.StreamedResponse>();
  final body = StreamController<List<int>>();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final abort = (request as http.Abortable).abortTrigger!;
    unawaited(
      abort.then((_) {
        aborted = true;
        if (!headers.isCompleted) {
          headers.completeError(http.RequestAbortedException());
        } else {
          body.addError(http.RequestAbortedException());
          unawaited(body.close());
        }
      }),
    );
    if (headersArrive) {
      headers.complete(http.StreamedResponse(body.stream, 200));
    }
    return headers.future;
  }
}

void main() {
  test('HTTP failure preserves the explicit room collision code', () async {
    final transport = HttpOnlineTransport(
      'https://example.test',
      client: MockClient(
        (request) async => http.Response(
          '{"error":"occupied","code":"ROOM_CODE_COLLISION"}',
          409,
        ),
      ),
    );
    addTearDown(transport.dispose);
    await expectLater(
      transport.request('POST', '/rooms', body: {}),
      throwsA(
        isA<OnlineFailure>()
            .having((e) => e.status, 'status', 409)
            .having((e) => e.code, 'code', 'ROOM_CODE_COLLISION'),
      ),
    );
  });
  for (final headersArrive in [false, true]) {
    test(
      'whole HTTP deadline aborts ${headersArrive ? 'body' : 'headers'} stall',
      () async {
        final client = _StalledClient(headersArrive: headersArrive);
        final transport = HttpOnlineTransport(
          'https://example.test',
          client: client,
          requestTimeout: const Duration(milliseconds: 30),
        );
        addTearDown(transport.dispose);
        await expectLater(
          transport.request('POST', '/rooms', body: {}),
          throwsA(
            isA<OnlineFailure>().having(
              (error) => error.message,
              'message',
              contains('時間'),
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(client.aborted, isTrue);
      },
    );
  }
}
