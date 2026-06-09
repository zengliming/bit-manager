import 'package:bit_manager/models/client_config.dart';
import 'package:bit_manager/providers/client_provider.dart';
import 'package:bit_manager/utils/http_client.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ClientConfig testClient(String id) => ClientConfig(
      id: id,
      name: 'Client $id',
      type: ClientType.qBittorrent,
      host: '127.0.0.1',
      port: 8080,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Mock flutter_secure_storage channel to avoid MissingPluginException
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        if (call.method == 'write') {
          return null;
        } else if (call.method == 'read') {
          return null;
        } else if (call.method == 'readAll') {
          return {};
        } else if (call.method == 'delete') {
          return null;
        } else if (call.method == 'deleteAll') {
          return null;
        }
        return null;
      },
    );
  });

  tearDown(() {
    HttpClientUtil.instance.clearClientDioCache();
  });

  group('Dio cache invalidation', () {
    test('addClient clears cached Dio instances', () async {
      final provider = ClientProvider();
      final config = testClient('client-1');

      // Create a cached Dio before adding the client
      final dioBefore = HttpClientUtil.instance.createClientDio(config);

      await provider.addClient(config);

      // After addClient, the cache should be cleared, so a new Dio instance
      // should be created for the same config
      final dioAfter = HttpClientUtil.instance.createClientDio(config);

      expect(dioBefore, isNot(same(dioAfter)));
    });

    test('updateClient clears cached Dio instances', () async {
      final provider = ClientProvider();
      final config = testClient('client-1');

      await provider.addClient(config);

      // Create a cached Dio after addClient
      final dioBefore = HttpClientUtil.instance.createClientDio(config);

      // Update the client (e.g., change timeout)
      final updated = config.copyWith(timeoutSeconds: 30);
      await provider.updateClient('client-1', updated);

      // After updateClient, the cache should be cleared
      // Create a new Dio for the updated config
      final dioAfter = HttpClientUtil.instance.createClientDio(updated);

      expect(dioBefore, isNot(same(dioAfter)));
      expect(dioAfter.options.connectTimeout, const Duration(seconds: 30));
    });

    test('deleteClient clears cached Dio instances', () async {
      final provider = ClientProvider();
      final config = testClient('client-1');

      await provider.addClient(config);

      // Create a cached Dio
      final dioBefore = HttpClientUtil.instance.createClientDio(config);

      await provider.deleteClient('client-1');

      // After deleteClient, the cache should be cleared
      final dioAfter = HttpClientUtil.instance.createClientDio(config);

      expect(dioBefore, isNot(same(dioAfter)));
    });
  });

  group('loadClients', () {
    test('notifies listeners when loading starts', () async {
      final provider = ClientProvider();
      int notifyCount = 0;
      provider.addListener(() {
        // Capture that notifyListeners was called after _loading = true
        if (provider.loading) notifyCount++;
      });

      await provider.loadClients();

      // Should have been notified at least once for loading = true
      // and once for loading = false (in finally block)
      expect(notifyCount, greaterThanOrEqualTo(1));
    });
  });
}
