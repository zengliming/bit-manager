import 'package:bit_manager/services/filters.dart';
import 'package:bit_manager/services/selector_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SelectorEngine — 标准 CSS', () {
    test('简单标签 + class 选择器', () {
      final doc = SelectorEngine.parse(
        '<div><p class="x">A</p><p class="y">B</p></div>',
      );
      final r = SelectorEngine.query(doc.documentElement!, 'p.x');
      expect(r, hasLength(1));
      expect(r.first.text, 'A');
    });

    test(':contains 单词', () {
      final doc = SelectorEngine.parse('''
<table>
  <tr><td class="rowhead">魔力值</td><td>1234</td></tr>
  <tr><td class="rowhead">分享率</td><td>2.5</td></tr>
</table>''');
      final r = SelectorEngine.query(
        doc.documentElement!,
        "td.rowhead:contains('魔力值') + td",
      );
      expect(r, hasLength(1));
      expect(r.first.text.trim(), '1234');
    });

    test(':contains 多个 AND（PT-depiler "Karma":contains("Points")）', () {
      final doc = SelectorEngine.parse('''
<table>
  <tr><td class="rowhead">Karma Points</td><td>5,000</td></tr>
  <tr><td class="rowhead">Karma</td><td>nope</td></tr>
</table>''');
      final r = SelectorEngine.query(
        doc.documentElement!,
        "td.rowhead:contains('Karma'):contains('Points') + td",
      );
      expect(r, hasLength(1));
      expect(r.first.text.trim(), '5,000');
    });

    test('> 子选择器（如 td > img）', () {
      final doc = SelectorEngine.parse('''
<table>
  <tr><td class="rowhead">等级</td>
      <td><img title="VIP" src="x.png"></td></tr>
</table>''');
      final r = SelectorEngine.query(
        doc.documentElement!,
        "td.rowhead:contains('等级') + td > img",
      );
      expect(r, hasLength(1));
      expect(r.first.attributes['title'], 'VIP');
    });

    test('找不到匹配返回空', () {
      final doc = SelectorEngine.parse('<p>x</p>');
      expect(
        SelectorEngine.query(doc.documentElement!, "td:contains('nope') + td"),
        isEmpty,
      );
    });
  });

  group('Filters', () {
    test('parseNumber 含千分位', () {
      expect(Filters.apply('12,345.6', 'parseNumber'), 12345.6);
    });
    test('parseNumber 取首段数字', () {
      expect(Filters.apply('魔力值: 1,234.5 (排名 5)', 'parseNumber'), 1234.5);
    });
    test('parseSize 二进制单位', () {
      expect(
        Filters.apply('1.5 TiB', 'parseSize'),
        (1.5 * 1099511627776).round(),
      );
    });
    test('parseSize 十进制单位', () {
      expect(Filters.apply('500 GB', 'parseSize'), 500000000000);
    });
    test('parseSize 取首段', () {
      expect(
        Filters.apply('上传量: 1.23 TB (实际 2x)', 'parseSize'),
        (1.23 * 1000000000000).round(),
      );
    });
    test('split index 0', () {
      expect(
        Filters.apply('2024-06-01 12:00:00 (1 年前)', {
          'name': 'split',
          'args': ['(', 0],
        }),
        '2024-06-01 12:00:00',
      );
    });
    test('querystring 取参数', () {
      expect(
        Filters.apply('/userdetails.php?id=42&x=1', {
          'name': 'querystring',
          'args': ['id'],
        }),
        '42',
      );
    });
    test('regex 取 group 1', () {
      expect(
        Filters.apply('foo: bar', {
          'name': 'regex',
          'args': [r'foo:\s*(\w+)'],
        }),
        'bar',
      );
    });
    test('applyAll 顺序应用', () {
      // "2024-06-01 (...)" → split 取第一段 → trim
      final r = Filters.applyAll('  2024-06-01 (xxx)  ', [
        {
          'name': 'split',
          'args': ['(', 0],
        },
        'trim',
      ]);
      expect(r, '2024-06-01');
    });
    test('未知 filter 透传原值', () {
      expect(Filters.apply('hello', 'no_such_filter'), 'hello');
    });
  });
}
