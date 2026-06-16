/// PT-depiler 兼容的命名 filter 集合
///
/// 对齐 `src/packages/site/utils.ts` 里的 `definedFilters`，但只实现
/// 站点 userInfo 字段实际用到的几种（其它过滤器在 PT-depiler 里很少出现）：
/// - parseNumber: "12,345.6" / "1.23 万" → number
/// - parseSize:   "1.23 TB" → 字节数
/// - parseTime:   "2024-06-01 12:00" → ISO 字符串（保持简单）
/// - split:       "x (y)".split("(", 0) → "x"
/// - querystring: "/userdetails.php?id=42&x=1" 取参数 "id" → "42"
/// - regex:       按提供的正则取 group(1)
class Filters {
  /// 应用一个 filter 描述符，返回结果（可能是 String / num / null）
  ///
  /// 描述符两种形式：
  /// - 简写字符串 "parseNumber"
  /// - 详细 Map {"name":"split","args":["(",0]}
  static Object? apply(Object? value, Object descriptor) {
    String name;
    List<Object?> args = const [];

    if (descriptor is String) {
      name = descriptor;
    } else if (descriptor is Map) {
      name = (descriptor['name'] as String?) ?? '';
      args = (descriptor['args'] as List?)?.cast<Object?>() ?? const [];
    } else {
      return value;
    }

    switch (name) {
      case 'parseNumber':
        return _parseNumber(value);
      case 'parseSize':
        return _parseSize(value);
      case 'parseTime':
        return _parseTime(value, args);
      case 'split':
        return _split(value, args);
      case 'querystring':
        return _querystring(value, args);
      case 'regex':
        return _regex(value, args);
      case 'trim':
        return value?.toString().trim();
      default:
        return value;
    }
  }

  /// 顺序应用一组 filter
  static Object? applyAll(Object? value, List<Object> filters) {
    var cur = value;
    for (final f in filters) {
      cur = apply(cur, f);
    }
    return cur;
  }

  // ── 内部实现 ──

  static num? _parseNumber(Object? v) {
    if (v == null) return null;
    final s = v.toString().replaceAll(',', '').trim();
    if (s.isEmpty) return null;
    // 取首段连续数字 / 小数
    final m = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(s);
    return m == null ? null : num.tryParse(m.group(0)!);
  }

  static int? _parseSize(Object? v) {
    if (v == null) return null;
    var s = v.toString().trim().replaceAll(',', '');
    if (s.isEmpty) return null;
    // 取「数字 单位」段（数字和单位之间允许空白），单位只取第一段连续字母（含 i）
    final m = RegExp(
      r'(-?\d+(?:\.\d+)?)\s*([ZEPTGMK]?i?B)\b',
      caseSensitive: false,
    ).firstMatch(s);
    if (m == null) {
      // 纯数字直接返回
      return int.tryParse(s);
    }
    final value = double.tryParse(m.group(1)!) ?? 0;
    final unit = m.group(2)!.toUpperCase();
    final factor = _sizeUnit(unit);
    if (factor == null) return null;
    return (value * factor).round();
  }

  static int? _sizeUnit(String unit) {
    switch (unit) {
      case 'TIB':
        return 1099511627776;
      case 'GIB':
        return 1073741824;
      case 'MIB':
        return 1048576;
      case 'KIB':
        return 1024;
      case 'TB':
        return 1000000000000;
      case 'GB':
        return 1000000000;
      case 'MB':
        return 1000000;
      case 'KB':
        return 1000;
      case 'B':
        return 1;
    }
    return null;
  }

  static String? _parseTime(Object? v, List<Object?> args) {
    if (v == null) return null;
    // 简单实现：返回原字符串去括号；时区/格式化交给消费方
    return v.toString().split('(').first.trim();
  }

  static String? _split(Object? v, List<Object?> args) {
    if (v == null || args.isEmpty) return v?.toString();
    final sep = args[0]?.toString() ?? '';
    final idx = args.length > 1 ? (args[1] as num?)?.toInt() ?? 0 : 0;
    final s = v.toString();
    if (sep.isEmpty) return s;
    final parts = s.split(sep);
    if (idx < 0 || idx >= parts.length) return null;
    return parts[idx].trim();
  }

  /// 从 URL / query string 中取参数。args[0] = 参数名
  static String? _querystring(Object? v, List<Object?> args) {
    if (v == null || args.isEmpty) return null;
    final name = args[0]?.toString();
    if (name == null) return null;
    final s = v.toString();
    final qIndex = s.indexOf('?');
    final qs = qIndex >= 0 ? s.substring(qIndex + 1) : s;
    for (final pair in qs.split('&')) {
      final eq = pair.indexOf('=');
      if (eq < 0) continue;
      if (pair.substring(0, eq) == name) {
        return Uri.decodeQueryComponent(pair.substring(eq + 1));
      }
    }
    return null;
  }

  /// 正则提取 group(1)。args[0]=pattern, args[1]=flags(可选 "i")
  static String? _regex(Object? v, List<Object?> args) {
    if (v == null || args.isEmpty) return null;
    final pattern = args[0]?.toString();
    if (pattern == null) return null;
    final flags = args.length > 1 ? args[1]?.toString() ?? '' : '';
    final caseSensitive = !flags.contains('i');
    final re = _getOrCompileRegex(pattern, caseSensitive);
    final m = re.firstMatch(v.toString());
    if (m == null) return null;
    if (m.groupCount >= 1) return m.group(1);
    return m.group(0);
  }

  /// RegExp 缓存 — 同一 (pattern, caseSensitive) 共享一个编译产物。
  /// 用户从 default_schema.json / 站点 JSON 加载的正则不会被 Dart 内置的
  /// 字符串字面量 pattern 缓存命中，必须显式缓存。
  static final Map<String, RegExp> _regexCache = {};
  static RegExp _getOrCompileRegex(String pattern, bool caseSensitive) {
    final key = '${caseSensitive ? "s" : "i"}|$pattern';
    return _regexCache.putIfAbsent(
      key,
      () => RegExp(pattern, caseSensitive: caseSensitive),
    );
  }
}
