import 'package:bit_manager/models/site_config.dart';
import 'package:bit_manager/providers/site_provider.dart';
import 'package:bit_manager/utils/storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

SiteConfig _site(String id, {bool active = true, String? type}) => SiteConfig(
      id: id,
      name: 'Site $id',
      baseUrl: 'https://$id.example.com',
      tags: const ['电影'],
      isActive: active,
      type: type,
    );

SiteUserInfo _info(
  String siteId, {
  bool fetchFailed = false,
  int? uploaded,
  int? downloaded,
  int? bonusPoints,
  int? seedingCount,
  int? seedingSize,
  int? messageCount,
  int? hnrPreWarning,
  int? hnrUnsatisfied,
  DateTime? lastFetchedAt,
}) =>
    SiteUserInfo(
      siteId: siteId,
      fetchFailed: fetchFailed,
      uploaded: uploaded,
      downloaded: downloaded,
      bonusPoints: bonusPoints,
      seedingCount: seedingCount,
      seedingSize: seedingSize,
      messageCount: messageCount,
      hnrPreWarning: hnrPreWarning,
      hnrUnsatisfied: hnrUnsatisfied,
      lastFetchedAt: lastFetchedAt,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalStorage.resetForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  test('siteStats 聚合多站点用户信息并跳过失败与公开站', () async {
    final provider = SiteProvider();
    await provider.addSite(_site('s1', active: true));
    await provider.addSite(_site('s2', active: true));
    await provider.addSite(_site('s3', active: false)); // 不活跃
    await provider.addSite(_site('pub', type: 'public')); // 公开站

    // 直接写内存用户信息（绕过网络抓取）
    await provider.updateUserInfo(_info('s1',
        uploaded: 1000,
        downloaded: 500,
        bonusPoints: 200,
        seedingCount: 5,
        seedingSize: 3000,
        messageCount: 2,
        hnrPreWarning: 1,
        hnrUnsatisfied: 0,
        lastFetchedAt: DateTime(2026, 6, 17, 10)));
    await provider.updateUserInfo(_info('s2',
        uploaded: 4000,
        downloaded: 1500,
        bonusPoints: 100,
        seedingCount: 7,
        seedingSize: 7000,
        messageCount: 0,
        lastFetchedAt: DateTime(2026, 6, 17, 12)));
    await provider.updateUserInfo(_info('s1-failed', fetchFailed: true)); // 不计入

    final stats = provider.siteStats;

    expect(stats.totalSites, 4);
    expect(stats.activeSites, 3);
    expect(stats.totalUploaded, 5000); // 1000 + 4000
    expect(stats.totalDownloaded, 2000); // 500 + 1500
    expect(stats.totalBonus, 300);
    expect(stats.totalSeedingCount, 12);
    expect(stats.totalSeedingSize, 10000);
    expect(stats.unreadTotal, 2);
    expect(stats.hnrPreWarningTotal, 1);
    expect(stats.hnrUnsatisfiedTotal, 0);
    expect(stats.lastRefreshAt, DateTime(2026, 6, 17, 12)); // 最大值
  });

  test('siteStats 无用户信息时 lastRefreshAt 为 null 且数值全 0', () async {
    final provider = SiteProvider();
    await provider.addSite(_site('s1'));

    final stats = provider.siteStats;

    expect(stats.totalSites, 1);
    expect(stats.activeSites, 1);
    expect(stats.totalUploaded, 0);
    expect(stats.unreadTotal, 0);
    expect(stats.lastRefreshAt, isNull);
  });
}
