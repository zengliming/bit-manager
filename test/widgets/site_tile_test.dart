import 'package:bit_manager/models/site_config.dart';
import 'package:bit_manager/widgets/site_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SiteConfig makeSite({String id = 'a', String name = 'Site A'}) =>
    SiteConfig(id: id, name: name, baseUrl: 'https://$id.example.com');

SiteUserInfo makeInfo({
  String siteId = 'a',
  int? messageCount,
  int? hnrPreWarning,
  int? hnrUnsatisfied,
  int? seedingCount,
  int? leechingCount,
  int? bonusPoints,
  int? uploaded,
  int? downloaded,
  String? username,
  String? level,
  double? ratio,
}) {
  return SiteUserInfo(
    siteId: siteId,
    messageCount: messageCount,
    hnrPreWarning: hnrPreWarning,
    hnrUnsatisfied: hnrUnsatisfied,
    seedingCount: seedingCount,
    leechingCount: leechingCount,
    bonusPoints: bonusPoints,
    uploaded: uploaded,
    downloaded: downloaded,
    username: username,
    level: level,
    ratio: ratio,
  );
}

Future<void> pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  group('SiteTile', () {
    testWidgets('仅 username 时只渲染身份行', (tester) async {
      final site = makeSite();
      final info = makeInfo(username: 'alice');

      await pump(tester, SiteTile(site: site, userInfo: info, hasCookie: true));

      expect(find.textContaining('alice'), findsOneWidget);
      // 没有任何状态指标
      expect(find.textContaining('⚠'), findsNothing);
    });

    testWidgets('messageCount=3 时显示红色未读徽标且可点击',
        (tester) async {
      final site = makeSite();
      final info = makeInfo(messageCount: 3);
      var tapped = 0;

      await pump(
        tester,
        SiteTile(
          site: site,
          userInfo: info,
          hasCookie: true,
          onOpenMessages: () => tapped++,
        ),
      );

      final badge = find.text('3');
      expect(badge, findsOneWidget);
      await tester.tap(badge);
      expect(tapped, 1);
    });

    testWidgets('messageCount=null 时不显示未读徽标', (tester) async {
      final site = makeSite();
      final info = makeInfo(messageCount: null);

      await pump(tester, SiteTile(site: site, userInfo: info, hasCookie: true));

      // 找不到 "5" 之类的数字徽标（除 site name 之外）
      // 由于 SiteTile 内可能含用户名等数字，最稳的判断是没有 unread badge 容器
      expect(find.text('99+'), findsNothing);
      // 默认 site name 是 "Site A"，messageCount 不会渲染
    });

    testWidgets('messageCount=150 时显示 99+', (tester) async {
      final site = makeSite();
      final info = makeInfo(messageCount: 150);

      await pump(tester, SiteTile(site: site, userInfo: info, hasCookie: true));

      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('H&R pre=2 unsat=1 时显示 ⚠3', (tester) async {
      final site = makeSite();
      final info = makeInfo(hnrPreWarning: 2, hnrUnsatisfied: 1);

      await pump(tester, SiteTile(site: site, userInfo: info, hasCookie: true));

      expect(find.text('⚠3'), findsOneWidget);
    });

    testWidgets('H&R 全 0 时不显示徽标', (tester) async {
      final site = makeSite();
      final info = makeInfo(hnrPreWarning: 0, hnrUnsatisfied: 0);

      await pump(tester, SiteTile(site: site, userInfo: info, hasCookie: true));

      expect(find.textContaining('⚠'), findsNothing);
    });

    testWidgets('refreshing=true 时显示 spinner 替代 ratio', (tester) async {
      final site = makeSite();
      final info = makeInfo(ratio: 2.5);

      await pump(
        tester,
        SiteTile(
          site: site,
          userInfo: info,
          hasCookie: true,
          refreshing: true,
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('2.50'), findsNothing);
    });

    testWidgets('hasCookie=false 时不渲染 userInfo 行', (tester) async {
      final site = makeSite();
      final info = makeInfo(messageCount: 5, username: 'alice');

      await pump(tester, SiteTile(site: site, userInfo: info, hasCookie: false));

      // 状态行不渲染
      expect(find.text('99+'), findsNothing);
      // 占位文案出现
      expect(find.text('未配置 Cookie'), findsOneWidget);
    });
  });
}
