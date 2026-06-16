import 'package:bit_manager/models/site_config.dart';
import 'package:bit_manager/services/site_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 测试套件统一加载默认 schema（rootBundle 在 widget test 里也能用）
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await SiteService.ensureDefaultSchemaLoaded();
  });
  group('fetchUserInfo', () {
    test('返回 null（cookie 为空）', () async {
      final service = SiteService();
      final config = SiteConfig(
        id: 'test',
        name: 'Test',
        baseUrl: 'https://example.com',
      );
      final result = await service.fetchUserInfo(config, null);
      expect(result, isNull);
    });

    test('返回 null（baseUrl 为空）', () async {
      final service = SiteService();
      final config = SiteConfig(id: 'test', name: 'Test');
      final result = await service.fetchUserInfo(config, 'uid=123');
      expect(result, isNull);
    });
  });

  group('parseSize', () {
    test('解析 "1.23 TB"', () {
      expect(SiteService.parseSize('1.23 TB'), closeTo(1230000000000, 1));
    });

    test('解析 "500 GB"', () {
      expect(SiteService.parseSize('500 GB'), closeTo(500000000000, 1));
    });

    test('解析 "100 MB"', () {
      expect(SiteService.parseSize('100 MB'), closeTo(100000000, 1));
    });

    test('解析 "50 KB"', () {
      expect(SiteService.parseSize('50 KB'), 50000);
    });

    test('解析纯数字', () {
      expect(SiteService.parseSize('12345'), 12345);
    });

    test('解析空字符串', () {
      expect(SiteService.parseSize(''), isNull);
      expect(SiteService.parseSize(null), isNull);
    });
  });

  group('parseRatio', () {
    test('解析 "2.5"', () {
      expect(SiteService.parseRatio('2.5'), closeTo(2.5, 0.01));
    });

    test('解析 "∞" 或 "Inf."', () {
      expect(SiteService.parseRatio('∞'), double.infinity);
      expect(SiteService.parseRatio('Inf.'), double.infinity);
    });

    test('解析空字符串', () {
      expect(SiteService.parseRatio(''), isNull);
    });
  });

  group('parseHtml — NexusPHP', () {
    const html = '''
<html><body>
<table id="info_block">
  <a href="/userdetails.php?id=12345" class="User_Name"><b>张三</b></a>
  [<a href="logout.php">退出</a>]
  <span>当前活动:</span>
  <img class="arrowup" alt="Upload"> <font class="color_uploaded">1.23 TB</font>
  <img class="arrowdown" alt="Download"> <font class="color_downloaded">456.78 GB</font>
  <font class="color_ratio"><b>2.690</b></font>
  魔力值: <font class="color_bonus">12,345.6</font>
  等级: <img class="userlevel" alt="VIP" src="/pic/class/9.png"> User Class: VIP
  当前做种: 42  当前下载: 3
</table>
</body></html>
''';

    test('提取用户名 / 上传 / 下载 / 分享率 / 魔力 / 等级 / 做种数', () {
      final info = SiteService().parseHtml('m-team', html);
      expect(info.username, '张三');
      expect(info.uploaded, closeTo(1.23 * 1000000000000, 1));
      expect(info.downloaded, closeTo(456.78 * 1000000000, 1));
      expect(info.ratio, closeTo(2.69, 0.001));
      expect(info.bonusPoints, 12345);
      expect(info.level, 'VIP');
      expect(info.seedingCount, 42);
      expect(info.leechingCount, 3);
      expect(info.fetchFailed, isFalse);
    });
  });

  group('parseHtml — Gazelle', () {
    const html = '''
<html><body>
<ul id="userinfo_username">
  <li><a href="user.php?id=42" class="username">RedUser</a></li>
</ul>
<ul id="userinfo_stats">
  <li id="stats_uploaded">Up: <span>2.50 TiB</span></li>
  <li id="stats_downloaded">Down: <span>1.00 TiB</span></li>
  <li id="stats_ratio">Ratio: <span>2.50</span></li>
</ul>
</body></html>
''';

    test('提取用户名 / 上传 / 下载 / 分享率', () {
      final info = SiteService().parseHtml('red', html);
      expect(info.username, 'RedUser');
      expect(info.uploaded, closeTo(2.5 * 1099511627776, 1));
      expect(info.downloaded, closeTo(1.0 * 1099511627776, 1));
      expect(info.ratio, closeTo(2.5, 0.001));
    });
  });

  group('parseHtml — 纯文本兜底', () {
    const html = '''
<div>
  <p>用户名: TestUser</p>
  <p>上传量: 999.99 GB</p>
  <p>下载量: 100.00 GB</p>
  <p>分享率: 9.99</p>
</div>
''';

    test('在没有特征 class/id 时也能提取', () {
      final info = SiteService().parseHtml('generic', html);
      expect(info.uploaded, closeTo(999.99 * 1000000000, 1));
      expect(info.downloaded, closeTo(100.0 * 1000000000, 1));
      expect(info.ratio, closeTo(9.99, 0.001));
    });
  });

  group('parseHtml — 等级提取', () {
    test(
      'NexusPHP：只有 <img class="userlevel" src=".../class/..." alt="...">，无「等级:」文字',
      () {
        const html = '''
<a href="userdetails.php?id=1">u</a>
<img class="userlevel_image" src="pic/class/Power_User.gif" alt="Power User">
''';
        final info = SiteService().parseHtml('s', html);
        expect(info.level, 'Power User');
      },
    );

    test('NexusPHP：src 含 /class/ 但无 userlevel class，仍能识别', () {
      const html = '''
<a href="userdetails.php?id=1">u</a>
身份: <img src="/pic/class/VIP.png" alt="VIP">
''';
      final info = SiteService().parseHtml('s', html);
      expect(info.level, 'VIP');
    });

    test('Windows 风格反斜杠 src 也能识别', () {
      const html = '''
<a href="userdetails.php?id=1">u</a>
<img class="userlevel" src="pic\\class\\Elite.gif" alt="Elite User">
''';
      final info = SiteService().parseHtml('s', html);
      expect(info.level, 'Elite User');
    });

    test('页面里有头像/箭头 img 但只有等级图带 /class/ 路径，不会误匹配', () {
      const html = '''
<a href="userdetails.php?id=1">u</a>
<img src="/avatar/abc.jpg" alt="avatar">
<img src="/pic/arrowup.gif" alt="up">
<img class="userlevel_image" src="/pic/class/Crazy_User.gif" alt="Crazy User">
''';
      final info = SiteService().parseHtml('s', html);
      expect(info.level, 'Crazy User');
    });

    test('纯文本「User Class: VIP」可识别（Gazelle 风格）', () {
      const html = '<p>User Class: VIP</p>';
      final info = SiteService().parseHtml('s', html);
      expect(info.level, 'VIP');
    });
  });

  group('parseIndexHtml — 首页阶段（PT-depiler 风格）', () {
    test('从 #info_block 内的 userdetails.php?id=N 取 userId + username', () {
      const html = '''
<table id="info_block">
  <a href="userdetails.php?id=12345" class="User_Name"><b>张三</b></a>
  <a href="messages.php">消息</a>
</table>
<a href="userdetails.php?id=99999">他人</a>
''';
      final info = SiteService().parseIndexHtml('s', html);
      // 不应该误抓到 info_block 外的他人 id
      expect(info.userId, '12345');
      expect(info.username, '张三');
    });

    test('Gazelle: user.php?id=N 也能识别', () {
      const html = '<a href="user.php?id=42" class="username">RedUser</a>';
      final info = SiteService().parseIndexHtml('s', html);
      expect(info.userId, '42');
      expect(info.username, 'RedUser');
    });

    test('cspt/财神 风格：头像链接在前，应跳过取后面的用户名链接', () {
      // 真实 cspt info_block 简化版：
      // 第一个 userdetails.php 链接是头像（<a><img alt="用户头像"></a>），
      // 第二个才是用户名（class="User_Name"）。
      const html = '''
<table id="info_block">
  <a href="userdetails.php?id=10010118" class="avatar">
    <img class="avatar_image" src="/avatars/abc.jpg" alt="用户头像">
  </a>
  <span>欢迎回来，</span>
  <a href="userdetails.php?id=10010118" class="User_Name"><b>zlmzzzz</b></a>
  <a href="logout.php">退出</a>
</table>
''';
      final info = SiteService().parseIndexHtml('cspt', html);
      expect(info.userId, '10010118');
      expect(
        info.username,
        'zlmzzzz',
        reason: '应跳过头像链接，取 class*="Name" 的用户名链接',
      );
    });

    test('avatar 标签为英文 "avatar" 也能识别', () {
      const html = '''
<a href="userdetails.php?id=999"><img alt="avatar" src="/x.jpg"></a>
<a href="userdetails.php?id=999" class="username">EnUser</a>
''';
      final info = SiteService().parseIndexHtml('s', html);
      expect(info.username, 'EnUser');
    });

    test('链接里只有 <img>（无 alt 文字）也会被跳过', () {
      const html = '''
<a href="userdetails.php?id=1"><img src="/x.jpg"></a>
<a href="userdetails.php?id=1" class="User_Name"><b>RealName</b></a>
''';
      final info = SiteService().parseIndexHtml('s', html);
      expect(info.username, 'RealName');
    });
  });

  group('parseIndexHtml — _pickUserDetailsLink 边界', () {
    test('class*=Name 的链接排在第二（首个 img 链接）时仍能挑中', () {
      // 这个 test 是对评分逻辑的健壮性测试：
      // 第一个链接没有 class*="Name"，第二个有 — Name 应胜出
      const html = '''
<table id="info_block">
  <a href="userdetails.php?id=99"><img src="/x.png" alt="avatar"></a>
  <a href="userdetails.php?id=99" class="User_Name"><b>Wanted</b></a>
</table>
''';
      final info = SiteService().parseIndexHtml('s', html);
      expect(info.userId, '99');
      expect(info.username, 'Wanted');
    });

    test('同位置出现两个 <img> 头像链接，只第一个有 Name class', () {
      // Name class 应当胜过"靠前"，即使在第二位
      const html = '''
<table id="info_block">
  <a href="userdetails.php?id=1"><img src="/x.png" alt="avatar"></a>
  <a href="userdetails.php?id=1"><img src="/y.png" alt="user pic"></a>
  <a href="userdetails.php?id=1" class="User_Name"><b>TheOne</b></a>
</table>
''';
      final info = SiteService().parseIndexHtml('s', html);
      expect(info.username, 'TheOne');
    });

    test('info_block 不存在时回退到全文档扫描', () {
      const html = '''
<a href="userdetails.php?id=42" class="User_Name"><b>FallbackUser</b></a>
''';
      final info = SiteService().parseIndexHtml('s', html);
      expect(info.userId, '42');
      expect(info.username, 'FallbackUser');
    });
  });

  group('mergeDetailHtml — 详情页阶段（PT-depiler NexusPHP schema）', () {
    // PT-depiler 已知的 td.rowhead 表格结构（https://github.com/pt-plugins/PT-depiler
    //   src/packages/site/schemas/NexusPHP.ts userInfo selectors）
    const html = '''
<table>
  <tr>
    <td class="rowhead">用户名</td>
    <td class="rowfollow">张三</td>
  </tr>
  <tr>
    <td class="rowhead">等级</td>
    <td class="rowfollow">
      <img class="userlevel" src="pic/class/Power_User.gif"
           title="Power User" alt="Power User">
    </td>
  </tr>
  <tr>
    <td class="rowhead">加入日期</td>
    <td class="rowfollow">2023-01-15 10:30:00 (1 年前)</td>
  </tr>
  <tr>
    <td class="rowhead">传输</td>
    <td class="rowfollow">
      上传量: 5.43 TiB ( 2X: 2.50 TiB )<br>
      下载量: 1.20 TiB<br>
      分享率: 4.525
    </td>
  </tr>
  <tr>
    <td class="rowhead">魔力值</td>
    <td class="rowfollow">12,345.67</td>
  </tr>
  <tr>
    <td class="rowhead">当前做种</td>
    <td class="rowfollow">128</td>
  </tr>
  <tr>
    <td class="rowhead">当前下载</td>
    <td class="rowfollow">3</td>
  </tr>
</table>
''';

    test('解析等级、传输、魔力、加入日期、做种 / 下载', () {
      final info = SiteUserInfo(siteId: 's', userId: '1');
      SiteService().mergeDetailHtml(info, html);

      expect(info.username, '张三');
      // 等级取 img title（PT-depiler 选 attr: 'title'，比 alt 更准）
      expect(info.level, 'Power User');
      expect(info.uploaded, closeTo(5.43 * 1099511627776, 1));
      expect(info.downloaded, closeTo(1.20 * 1099511627776, 1));
      expect(info.ratio, closeTo(4.525, 0.001));
      expect(info.bonusPoints, 12345);
      expect(info.seedingCount, 128);
      expect(info.leechingCount, 3);
      // 加入日期保留为字符串（按 PT-depiler 习惯把括号后内容剥掉）
      expect(info.joinedAtText, '2023-01-15 10:30:00');
    });

    test('英文站点（rowhead 用 Class / Transfers）也能解析', () {
      const enHtml = '''
<table>
  <tr><td class="rowhead">Class</td>
      <td class="rowfollow"><img title="Elite User" src="/pic/class/elite.png"></td></tr>
  <tr><td class="rowhead">Transfers</td>
      <td class="rowfollow">
        Uploaded: 999.99 GB<br>
        Downloaded: 100.00 GB<br>
        Ratio: 9.99
      </td></tr>
  <tr><td class="rowhead">Karma Points</td><td class="rowfollow">5,000</td></tr>
  <tr><td class="rowhead">Join date</td><td class="rowfollow">2024-06-01 12:00:00</td></tr>
</table>
''';
      final info = SiteUserInfo(siteId: 's');
      SiteService().mergeDetailHtml(info, enHtml);
      expect(info.level, 'Elite User');
      expect(info.uploaded, closeTo(999.99 * 1000000000, 1));
      expect(info.downloaded, closeTo(100.0 * 1000000000, 1));
      expect(info.ratio, closeTo(9.99, 0.001));
      expect(info.bonusPoints, 5000);
      expect(info.joinedAtText, '2024-06-01 12:00:00');
    });

    test('13city 风格（"魔力值" 改名为 "啤酒瓶"）通过 schema 自定义标签解析', () {
      // 取自 PT-depiler 13city.ts userInfo.selectors.bonus 覆写
      const html = '''
<table>
  <tr><td class="rowhead">啤酒瓶</td>
      <td class="rowfollow">8,888.5</td></tr>
</table>
''';
      final info = SiteUserInfo(siteId: '13city');
      // 不指定 schema：默认标签里没有"啤酒瓶"，应当抓不到
      SiteService().mergeDetailHtml(info, html);
      expect(info.bonusPoints, isNull, reason: '默认标签里没有"啤酒瓶"');

      final info2 = SiteUserInfo(siteId: '13city');
      SiteService().mergeDetailHtml(
        info2,
        html,
        schema: const SiteParseSchema(bonusLabels: ['啤酒瓶']),
      );
      expect(info2.bonusPoints, 8888);
    });

    test('zrpt 风格（带冒号的标签 "积分:"）会被 trim 后正确匹配', () {
      const html = '''
<table>
  <tr><td class="rowhead">积分</td>
      <td class="rowfollow">12,345</td></tr>
</table>
''';
      final info = SiteUserInfo(siteId: 'zrpt');
      SiteService().mergeDetailHtml(
        info,
        html,
        schema: const SiteParseSchema(bonusLabels: ['积分']),
      );
      expect(info.bonusPoints, 12345);
    });

    test('PT-depiler 风格 schema.fields：selector + filter 全字段', () {
      // 模拟一个典型 NexusPHP 详情页
      const html = '''
<table>
  <tr><td class="rowhead">用户名</td><td class="rowfollow">testuser</td></tr>
  <tr><td class="rowhead">等级</td>
      <td class="rowfollow"><img title="Power User" alt="Power User"></td></tr>
  <tr><td class="rowhead">啤酒瓶</td><td class="rowfollow">8,888.5</td></tr>
  <tr><td class="rowhead">加入日期</td><td class="rowfollow">2025-01-15 10:00:00 (1 个月前)</td></tr>
  <tr><td class="rowhead">当前做种</td><td class="rowfollow">42</td></tr>
</table>
''';
      final info = SiteUserInfo(siteId: '13city');
      SiteService().mergeDetailHtml(
        info,
        html,
        schema: SiteParseSchema(
          fields: {
            'name': const FieldRule(
              selector: ["td.rowhead:contains('用户名') + td"],
            ),
            'levelName': const FieldRule(
              selector: ["td.rowhead:contains('等级') + td > img"],
              attr: 'title',
            ),
            'bonus': const FieldRule(
              selector: ["td.rowhead:contains('啤酒瓶') + td"],
              filter: 'parseNumber',
            ),
            'joinTime': const FieldRule(
              selector: ["td.rowhead:contains('加入日期') + td"],
              filter: {
                'name': 'split',
                'args': ['(', 0],
              },
            ),
            'seeding': const FieldRule(
              selector: ["td.rowhead:contains('当前做种') + td"],
              filter: 'parseNumber',
            ),
          },
        ),
      );
      expect(info.username, 'testuser');
      expect(info.level, 'Power User');
      expect(info.bonusPoints, 8888);
      expect(info.joinedAtText, '2025-01-15 10:00:00');
      expect(info.seedingCount, 42);
    });

    test('schema.fields 没覆盖的字段会回退到默认 td.rowhead 标签词路径', () {
      const html = '''
<table>
  <tr><td class="rowhead">魔力值</td><td class="rowfollow">9,999</td></tr>
  <tr><td class="rowhead">分享率</td><td class="rowfollow">2.5</td></tr>
</table>
''';
      final info = SiteUserInfo(siteId: 's');
      // schema 里只声明了 bonus，但页面里 bonus 是默认"魔力值"，rule 用了正确的 selector
      SiteService().mergeDetailHtml(
        info,
        html,
        schema: SiteParseSchema(
          fields: {
            'bonus': const FieldRule(
              selector: ["td.rowhead:contains('魔力值') + td"],
              filter: 'parseNumber',
            ),
          },
        ),
      );
      expect(info.bonusPoints, 9999);
    });

    test(
      '默认 NexusPHP schema 一次性抓全 messageCount/seedingBonus/lastAccessAt/H&R 等字段',
      () {
        // 完整 NexusPHP userdetails.php 模拟
        const html = '''
<table id="info_block">
  <tr>
    <td>
      <a href="userdetails.php?id=42" class="User_Name"><b>tester</b></a>
      <a href="myhr.php">H&R: 1/2</a>
      <td style="background: red"><a href="messages.php">3 条新消息</a></td>
    </td>
  </tr>
</table>
<table>
  <tr><td class="rowhead">用户名</td><td class="rowfollow">tester</td></tr>
  <tr><td class="rowhead">等级</td>
      <td class="rowfollow"><img title="Power User" alt="PU" src="/pic/class/pu.png"></td></tr>
  <tr><td class="rowhead">传输</td>
      <td class="rowfollow">
        上传量: 5.43 TiB (实际上传量: 2.50 TiB)<br>
        下载量: 1.20 TiB (实际下载量: 1.00 TiB)<br>
        分享率: 4.525
      </td></tr>
  <tr><td class="rowhead">做种积分</td><td class="rowfollow">123,456</td></tr>
  <tr><td class="rowhead">最近动向</td><td class="rowfollow">2025-06-10 15:30:00 (12 分钟前)</td></tr>
  <tr><td class="rowhead">加入日期</td><td class="rowfollow">2023-01-15 10:30:00 (2 年前)</td></tr>
</table>
''';
        final info = SiteUserInfo(siteId: 's');
        SiteService().mergeDetailHtml(info, html);

        expect(info.username, 'tester');
        expect(info.level, 'Power User');
        expect(info.uploaded, closeTo(5.43 * 1099511627776, 1));
        expect(info.trueUploaded, closeTo(2.50 * 1099511627776, 1));
        expect(info.downloaded, closeTo(1.20 * 1099511627776, 1));
        expect(info.trueDownloaded, closeTo(1.00 * 1099511627776, 1));
        expect(info.ratio, closeTo(4.525, 0.001));
        expect(info.seedingBonus, 123456);
        expect(info.messageCount, 3);
        expect(info.hnrPreWarning, 1);
        expect(info.hnrUnsatisfied, 2);
        expect(info.lastAccessAtText, '2025-06-10 15:30:00');
        expect(info.joinedAtText, '2023-01-15 10:30:00');
      },
    );

    test('未读消息没出现（无红色背景 td）时 messageCount 保持 null', () {
      const html = '''
<table>
  <tr><td class="rowhead">用户名</td><td class="rowfollow">u</td></tr>
</table>
''';
      final info = SiteUserInfo(siteId: 's');
      SiteService().mergeDetailHtml(info, html);
      expect(info.messageCount, isNull);
    });

    test('id 字段 setter 防御：拿到非数字值（用户名）时 userId 保持 null', () {
      const html = '''
<table>
  <tr><td class="rowhead">用户名</td>
      <td class="rowfollow"><a href="userdetails.php?id=10010118" class="User_Name">张三</a></td></tr>
</table>
''';
      // 把 selector 故意指向「用户名 td」而不是 href — 模拟用户配错规则
      final info = SiteUserInfo(siteId: 's');
      SiteService().mergeDetailHtml(
        info,
        html,
        schema: SiteParseSchema(
          fields: {
            'id': const FieldRule(
              selector: ["td.rowhead:contains('用户名') + td"],
            ),
          },
        ),
      );
      expect(info.userId, isNull, reason: 'id setter 应拒绝非数字值，不能把「张三」当 id 存');
    });

    test('id 字段 setter：数字字符串或整型都可接受', () {
      const html = '''
<table>
  <tr><td><a href="userdetails.php?id=42">x</a></td></tr>
</table>
''';
      final info1 = SiteUserInfo(siteId: 's');
      SiteService().mergeDetailHtml(
        info1,
        html,
        schema: SiteParseSchema(
          fields: {
            'id': const FieldRule(
              selector: ["a[href*='userdetails.php']"],
              attr: 'href',
            ),
          },
        ),
      );
      // 不会直接当 id（href 是整个 URL "userdetails.php?id=42"，不是纯数字）
      // 但应被识别并通过
      expect(info1.userId, isNull);

      final info2 = SiteUserInfo(siteId: 's');
      SiteService().mergeDetailHtml(
        info2,
        html,
        schema: SiteParseSchema(
          fields: {
            'id': const FieldRule(
              selector: ["a[href*='userdetails.php']"],
              attr: 'href',
              filter: {
                'name': 'querystring',
                'args': ['id'],
              },
            ),
          },
        ),
      );
      expect(info2.userId, '42');
    });
  });

  group('FieldRule JSON round-trip（filter / filters 兼容）', () {
    test('单数 filter 字段加载后等价于 filters:[filter]', () {
      // 模拟编辑器保存后磁盘里的 JSON 形态
      final rule = FieldRule.fromJson({
        'selector': ["td[href*='userdetails.php']"],
        'attr': 'href',
        'filter': 'parseNumber',
      });
      expect(rule.selector, hasLength(1));
      // 单 filter 也被规范进 filters，_runFieldRule 走 filters 路径
      expect(rule.filters, isNotNull);
      expect(rule.filters, hasLength(1));
      expect(rule.filters!.first, 'parseNumber');
    });

    test('filter 包装为 {name, args} 时 args 完整保留', () {
      final rule = FieldRule.fromJson({
        'selector': ["x"],
        'filter': {
          'name': 'split',
          'args': ['(', 0],
        },
      });
      expect(rule.filters, hasLength(1));
      final f = rule.filters!.first as Map;
      expect(f['name'], 'split');
      expect(f['args'], ['(', 0]);
    });

    test('单数 filter 与复数 filters 同时存在时优先 filters', () {
      final rule = FieldRule.fromJson({
        'selector': ["x"],
        'filter': 'parseNumber',
        'filters': ['parseSize', 'trim'],
      });
      expect(rule.filters, ['parseSize', 'trim']);
    });
  });

  group('SiteService.runFieldRulesForPreview', () {
    test('返回每字段命中值', () {
      const html = '''
<table>
  <tr><td class="rowhead">等级</td>
      <td class="rowfollow"><img title="VIP" src="/x.png"></td></tr>
  <tr><td class="rowhead">啤酒瓶</td><td class="rowfollow">8,888</td></tr>
</table>
''';
      final results = SiteService.runFieldRulesForPreview(html, {
        'levelName': const FieldRule(
          selector: ["td.rowhead:contains('等级') + td > img"],
          attr: 'title',
        ),
        'bonus': const FieldRule(
          selector: ["td.rowhead:contains('啤酒瓶') + td"],
          filter: 'parseNumber',
        ),
      });
      expect(results['level'], 'VIP');
      expect(results['bonusPoints'], 8888);
    });
  });

  group('多 schema 加载', () {
    test('ensureDefaultSchemaLoaded 后 NexusPHP 与 Gazelle 都在内存', () async {
      // 重置以便能再加载
      SiteService.resetDefaultFieldsForTest();
      await SiteService.ensureDefaultSchemaLoaded();
      final nexus = SiteService.defaultFieldsForTest('NexusPHP');
      final gazelle = SiteService.defaultFieldsForTest('Gazelle');
      expect(nexus, isNotNull);
      expect(gazelle, isNotNull);
      expect(nexus!.containsKey('uploaded'), isTrue);
      expect(gazelle!.containsKey('uploaded'), isTrue);
    });

    test('NexusPHP 默认规则包含 name / seeding / leeching', () async {
      SiteService.resetDefaultFieldsForTest();
      await SiteService.ensureDefaultSchemaLoaded();
      final nexus = SiteService.defaultFieldsForTest('NexusPHP')!;
      expect(nexus.containsKey('name'), isTrue);
      expect(nexus.containsKey('seeding'), isTrue);
      expect(nexus.containsKey('leeching'), isTrue);
      // JSON 中的 "filter": "parseNumber" 在 fromJson 时被规范化进 filters 列表
      expect(nexus['seeding']!.filters, isNotNull);
      expect(nexus['seeding']!.filters!.contains('parseNumber'), isTrue);
      expect(nexus['leeching']!.filters!.contains('parseNumber'), isTrue);
    });

    test('schema 为 null 时回落到 NexusPHP', () async {
      SiteService.resetDefaultFieldsForTest();
      await SiteService.ensureDefaultSchemaLoaded();
      // parseHtml 使用 schema=null
      final svc = SiteService();
      final html =
          '<html><body><table>'
          "<tr><td class='rowhead'>传输</td><td>上传量: 1.00 TB 下载量: 2.00 TB 分享率: 0.50</td></tr>"
          '</table></body></html>';
      final info = svc.parseHtml('test', html, schema: null);
      expect(info.uploaded, isNotNull);
    });

    test('schema 为 Gazelle 时使用 Gazelle 默认规则', () async {
      SiteService.resetDefaultFieldsForTest();
      await SiteService.ensureDefaultSchemaLoaded();
      final svc = SiteService();
      // Gazelle 风格 HTML：li#stats_uploaded 内有纯文本"2.5 TiB"
      final html =
          '<html><body>'
          '<li id="stats_uploaded">2.5 TiB</li>'
          '<li id="stats_downloaded">1.0 TiB</li>'
          '<li id="stats_ratio">2.5</li>'
          '</body></html>';
      final info = svc.parseHtml(
        'test',
        html,
        schema: const SiteParseSchema(schema: 'Gazelle'),
      );
      expect(info.uploaded, equals(2748779069440)); // 2.5 TiB
      expect(info.downloaded, equals(1099511627776)); // 1.0 TiB
      expect(info.ratio, closeTo(2.5, 0.01));
    });

    test('站点自定义 fields 优先于默认规则', () async {
      SiteService.resetDefaultFieldsForTest();
      await SiteService.ensureDefaultSchemaLoaded();
      final svc = SiteService();
      // NexusPHP 默认会从 td.rowhead:contains('传输') + td 拿上传量
      // 站点自定义 fields 用 contains 过滤拿 42 GB
      final html =
          '<html><body><table>'
          "<tr><td class='rowhead'>传输</td><td>上传量: 999 TB 下载量: 1.00 TB</td></tr>"
          "<tr><td>专用区</td><td>42 GB</td></tr>"
          '</table></body></html>';
      // package:html 不支持 td.classname；用 td + contains 过滤
      final customRule = const FieldRule(
        selector: ["td"],
        contains: '42 GB',
        filter: 'parseSize',
      );
      final schema = SiteParseSchema(
        schema: 'NexusPHP',
        fields: {'uploaded': customRule},
      );
      final info = svc.parseHtml('test', html, schema: schema);
      // 自定义规则拿到的 42 GB（42,000,000,000 — 十进制单位）优先于默认拿到的 999 TB
      expect(info.uploaded, equals(42000000000));
    });
  });
}
