import 'package:bit_manager/models/client_config.dart';
import 'package:bit_manager/utils/http_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ClientConfig clientWithTimeout(int timeoutSeconds) => ClientConfig(
        id: 'client-$timeoutSeconds',
        name: 'Client $timeoutSeconds',
        type: ClientType.qBittorrent,
        host: '127.0.0.1',
        port: 8080,
        timeoutSeconds: timeoutSeconds,
      );

  tearDown(() {
    HttpClientUtil.instance.clearClientDioCache();
  });

  test('createClientDio does not reuse a cached Dio with a different timeout', () {
    final util = HttpClientUtil.instance;

    final fast = util.createClientDio(clientWithTimeout(5));
    final slow = util.createClientDio(clientWithTimeout(30));

    expect(fast, isNot(same(slow)));
    expect(fast.options.connectTimeout, const Duration(seconds: 5));
    expect(slow.options.connectTimeout, const Duration(seconds: 30));
    expect(slow.options.receiveTimeout, const Duration(seconds: 35));
    expect(slow.options.sendTimeout, const Duration(seconds: 35));
  });

  test('clearClientDioCache forces a new Dio for the same configuration', () {
    final util = HttpClientUtil.instance;
    final config = clientWithTimeout(10);

    final first = util.createClientDio(config);
    util.clearClientDioCache();
    final second = util.createClientDio(config);

    expect(first, isNot(same(second)));
  });
}
