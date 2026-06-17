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

  test('SiteStats 持有全部汇总字段', () {
    final stats = SiteStats(
      totalSites: 5,
      activeSites: 4,
      sitesWithCookie: 3,
      totalUploaded: 1000,
      totalDownloaded: 500,
      totalBonus: 200,
      totalSeedingCount: 12,
      totalSeedingSize: 3000,
      unreadTotal: 2,
      hnrPreWarningTotal: 1,
      hnrUnsatisfiedTotal: 0,
      lastRefreshAt: null,
    );
    expect(stats.totalSites, 5);
    expect(stats.activeSites, 4);
    expect(stats.sitesWithCookie, 3);
    expect(stats.totalUploaded, 1000);
    expect(stats.totalDownloaded, 500);
    expect(stats.totalBonus, 200);
    expect(stats.totalSeedingCount, 12);
    expect(stats.totalSeedingSize, 3000);
    expect(stats.unreadTotal, 2);
    expect(stats.hnrPreWarningTotal, 1);
    expect(stats.hnrUnsatisfiedTotal, 0);
    expect(stats.lastRefreshAt, isNull);
  });
}
