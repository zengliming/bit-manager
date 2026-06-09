import 'package:bit_manager/models/client_config.dart';
import 'package:bit_manager/services/transmission_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestTransmissionService extends TransmissionService {
  @override
  Future<String?> debugGetSessionIdForTest(ClientConfig config) async =>
      'test-sid';

  @override
  Future<Map<String, dynamic>> debugRpcCallForTest(
    ClientConfig config,
    String method, {
    Map<String, dynamic>? args,
    String? sessionId,
  }) async {
    if (method == 'torrent-get' || method == 'torrent-stop') {
      return {
        'arguments': {
          'torrents': [
            {'id': 1, 'hashString': 'known'},
          ],
        },
      };
    }
    return {'arguments': {}};
  }
}

void main() {
  ClientConfig config() => ClientConfig(
    id: 'tr',
    name: 'Transmission',
    type: ClientType.transmission,
    host: '127.0.0.1',
    port: 9091,
  );

  test(
    'pauseTorrents throws when not all hashes resolve to Transmission ids',
    () async {
      final service = _TestTransmissionService();
      final cfg = config();

      expect(
        () => service.pauseTorrents(cfg, ['known', 'missing']),
        throwsA(
          predicate(
            (e) =>
                e is Exception &&
                e.toString().contains('Unable to resolve torrent hashes'),
          ),
        ),
      );
    },
  );
}
