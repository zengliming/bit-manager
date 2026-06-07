import 'package:bit_manager/models/client_config.dart';
import 'package:bit_manager/models/stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GlobalStats exposes active upload, checking, and waiting counts', () {
    final stats = GlobalStats(
      uploadingCount: 2,
      checkingCount: 3,
      waitingCount: 4,
    );

    expect(stats.uploadingCount, 2);
    expect(stats.checkingCount, 3);
    expect(stats.waitingCount, 4);
  });

  test('GlobalStats new count fields default to zero', () {
    final stats = GlobalStats();

    expect(stats.uploadingCount, 0);
    expect(stats.checkingCount, 0);
    expect(stats.waitingCount, 0);
  });

  test('ClientStats exposes active upload count', () {
    final stats = ClientStats(
      clientId: 'client-1',
      clientName: 'Client 1',
      type: ClientType.qBittorrent,
      uploadingCount: 5,
    );

    expect(stats.uploadingCount, 5);
  });

  test('ClientStats active upload count defaults to zero', () {
    final stats = ClientStats(
      clientId: 'client-1',
      clientName: 'Client 1',
      type: ClientType.qBittorrent,
    );

    expect(stats.uploadingCount, 0);
  });
}
