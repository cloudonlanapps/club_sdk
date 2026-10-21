import 'package:club_sdk_2/remote_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

/// A caller-owned client that records whether it was closed.
class _OwnedClient extends http.BaseClient {
  final _inner = MockClient((_) async => http.Response('{}', 200));
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request);

  @override
  void close() {
    closed = true;
    _inner.close();
  }
}

/// Issue 43: RemoteStore.dispose closes only a client it made.
void main() {
  group('Issue 43: RemoteStore.dispose', () {
    test('Issue 43: dispose leaves a client the caller passed in open', () {
      final shared = _OwnedClient();
      RemoteStore(baseUrl: 'https://example.test/v1', client: shared).dispose();
      // Today: dispose() closes it, so every other user of `shared` fails.
      expect(shared.closed, isFalse);
    });

    test(
      'Issue 43: dispose is safe to call on a store that made its own client',
      () {
        expect(
          () => RemoteStore(baseUrl: 'https://example.test/v1').dispose(),
          returnsNormally,
        );
      },
    );
  });
}
