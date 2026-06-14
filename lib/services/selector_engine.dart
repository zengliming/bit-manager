import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

/// 站点解析的 CSS 选择器引擎，对齐 PT-depiler 的 Sizzle 用法
///
/// 标准 CSS 不支持 jQuery 的 `:contains('xxx')`，我们在执行前解析它，
/// 切成「pre :contains('x') post」三段：先按 pre 选元素，过滤 textContent
/// 包含 x 的，再按 post 继续走标准选择器。
///
/// 支持组合：
///   td.rowhead:contains('魔力值') + td
///   td.rowhead:contains('Karma'):contains('Points') + td
///   td.rowhead:contains('等级') + td > img
///
/// 不支持：复杂的多级 :contains() 嵌套（PT-depiler 也很少用）
class SelectorEngine {
  /// 解析 HTML，返回 Document
  static Document parse(String html) => html_parser.parse(html);

  /// 在 root 下按 selector 查所有匹配元素
  static List<Element> query(Element root, String selector) {
    final s = selector.trim();
    if (s.isEmpty) return const [];

    // 找所有 :contains('xxx') 段
    final containsRe = RegExp(
      r'''(:contains\(\s*['"]([^'"]+)['"]\s*\))''',
      caseSensitive: false,
    );
    final matches = containsRe.allMatches(s).toList();
    if (matches.isEmpty) {
      // 没有 :contains，直接走标准 CSS
      return _safeQuery(root, s);
    }

    // 拆成: prefix（含 :contains 之前的部分）、contains 词、suffix（剩余）
    // 多个 :contains 连续出现时，全部都是 AND 条件（同一元素的 textContent 必须都包含）
    // 例：td.rowhead:contains('Karma'):contains('Points') + td
    //   prefix = "td.rowhead"
    //   containsWords = ["Karma", "Points"]
    //   suffix = " + td"
    final firstStart = matches.first.start;
    final prefix = s.substring(0, firstStart).trim();

    // 收集连续的 :contains 标签词
    final containsWords = <String>[];
    int idx = 0;
    int cursor = firstStart;
    while (idx < matches.length && matches[idx].start == cursor) {
      containsWords.add(matches[idx].group(2)!);
      cursor = matches[idx].end;
      idx++;
    }
    final suffix = s.substring(cursor).trim();

    if (idx < matches.length) {
      // 还有不连续的 :contains —— 复杂情况（如 a:contains('x') b:contains('y')），
      // 目前不支持。PT-depiler 没用过。
      assert(false,
          'SelectorEngine: 不连续 :contains 暂不支持，selector="$s"');
      return const [];
    }

    // 1) 按 prefix 选元素（prefix 可以为空，表示 root 内任意元素）
    final candidates = prefix.isEmpty
        ? root.querySelectorAll('*')
        : _safeQuery(root, prefix);

    // 2) 过滤 textContent 包含全部 containsWords
    final filtered = candidates.where((el) {
      final text = el.text;
      for (final w in containsWords) {
        if (!text.contains(w)) return false;
      }
      return true;
    }).toList();

    // 3) 按 suffix 继续走（如 "+ td"、"> img"）
    if (suffix.isEmpty) return filtered;

    // 处理常见的相邻 / 子选择器
    return filtered.expand((el) => _walk(el, suffix)).toList();
  }

  /// 在 [el] 上应用一个以 combinator 开头的 suffix（"+ td", "> img" 等）
  static Iterable<Element> _walk(Element el, String suffix) {
    final s = suffix.trim();

    // 邻接兄弟: + sel
    if (s.startsWith('+')) {
      final rest = s.substring(1).trim();
      final next = el.nextElementSibling;
      if (next == null) return const [];
      return _matchSelf(next, rest);
    }
    // 后续兄弟: ~ sel
    if (s.startsWith('~')) {
      final rest = s.substring(1).trim();
      final out = <Element>[];
      var sib = el.nextElementSibling;
      while (sib != null) {
        out.addAll(_matchSelf(sib, rest));
        sib = sib.nextElementSibling;
      }
      return out;
    }
    // 子: > sel
    if (s.startsWith('>')) {
      final rest = s.substring(1).trim();
      return el.children.expand((c) => _matchSelf(c, rest));
    }
    // 后代: 默认空白分隔
    // 如 ":contains('x') + td" 已处理过 +；这里处理 "td.rowhead:contains() td"
    return _safeQuery(el, s);
  }

  /// 如果 [el] 自身匹配 selector，返回 [el]；selector 含 combinator 则递归
  static Iterable<Element> _matchSelf(Element el, String selector) {
    final s = selector.trim();
    if (s.isEmpty) return [el];
    // selector 里仍可能含 combinator（"img > .x"），切第一个 token
    final firstCombinator = RegExp(r'[ +>~]').firstMatch(s);
    String first;
    String rest;
    if (firstCombinator == null) {
      first = s;
      rest = '';
    } else {
      first = s.substring(0, firstCombinator.start).trim();
      rest = s.substring(firstCombinator.start).trim();
    }
    if (!_elementMatches(el, first)) return const [];
    if (rest.isEmpty) return [el];
    return _walk(el, rest);
  }

  /// 安全地调 querySelectorAll，避开 package:html 解析失败时抛异常
  static List<Element> _safeQuery(Element root, String selector) {
    try {
      return root.querySelectorAll(selector);
    } catch (_) {
      return const [];
    }
  }

  static bool _elementMatches(Element el, String selector) {
    if (selector.isEmpty || selector == '*') return true;
    try {
      // package:html 没有 element.matches；用变通法：在父级 querySelectorAll 然后看是否包含本元素
      final parent = el.parent ?? el;
      final list = parent.querySelectorAll(selector);
      return list.contains(el);
    } catch (_) {
      return false;
    }
  }
}
