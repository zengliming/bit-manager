import 'package:dio/dio.dart';
import '../models/site_config.dart';

class SiteService {
  final Dio _dio;

  SiteService()
      : _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));

  /// 抓取站点用户信息
  /// 返回 null 表示抓取失败
  Future<SiteUserInfo?> fetchUserInfo(SiteConfig config, String? cookie) async {
    if (cookie == null || cookie.isEmpty) return null;
    if (config.baseUrl == null || config.baseUrl!.isEmpty) return null;

    try {
      final response = await _dio.get(
        config.baseUrl!,
        options: Options(
          headers: {'Cookie': cookie},
          followRedirects: true,
          responseType: ResponseType.plain,
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      if (response.statusCode != 200) return null;

      final html = response.data?.toString() ?? '';
      if (html.isEmpty) return null;

      return _parseHtml(config.id, html);
    } catch (_) {
      return null;
    }
  }

  /// 从 HTML 中提取用户信息
  SiteUserInfo _parseHtml(String siteId, String html) {
    final info = SiteUserInfo(siteId: siteId);

    // 用户名
    final usernamePatterns = [
      RegExp(r'class="[^"]*username[^"]*"[^>]*>([^<]+)<'),
      RegExp(r'id="userinfo"[^>]*>.*?<a[^>]*>([^<]+)<'),
      RegExp(r'<a[^>]*href="[^"]*user[^"]*"[^>]*>([^<]+)</a>'),
    ];
    for (final p in usernamePatterns) {
      final m = p.firstMatch(html);
      if (m != null) {
        info.username = m.group(1)?.trim();
        break;
      }
    }

    // 分享率
    info.ratio = _extractNumber(
      html,
      patterns: [
        RegExp(r'(?:分享率|ratio|分享比率)[\s:：]*([\d.]+|∞|Inf\.)'),
        RegExp(r'id="ratio"[^>]*>([^<]+)<'),
      ],
      parser: parseRatio,
    );

    // 上传量
    info.uploaded = _extractNumber(
      html,
      patterns: [
        RegExp(
            r'(?:上传|uploaded|上传量)[\s:：]*([\d.]+\s*(?:TB|GB|MB|KB|B|TiB|GiB|MiB|KiB))'),
        RegExp(r'id="uploaded"[^>]*>([^<]+)<'),
      ],
      parser: parseSize,
    );

    // 下载量
    info.downloaded = _extractNumber(
      html,
      patterns: [
        RegExp(
            r'(?:下载|downloaded|下载量)[\s:：]*([\d.]+\s*(?:TB|GB|MB|KB|B|TiB|GiB|MiB|KiB))'),
        RegExp(r'id="downloaded"[^>]*>([^<]+)<'),
      ],
      parser: parseSize,
    );

    // 等级
    final levelPatterns = [
      RegExp(r'(?:等级|class|用户等级)[\s:：]*<[^>]*>([^<]+)<'),
      RegExp(r'class="[^"]*level[^"]*"[^>]*>([^<]+)<'),
    ];
    for (final p in levelPatterns) {
      final m = p.firstMatch(html);
      if (m != null) {
        info.level = m.group(1)?.trim();
        break;
      }
    }

    // 魔力值
    info.bonusPoints = _extractNumber(
      html,
      patterns: [
        RegExp(r'(?:魔力|bonus|积分|Karma|BP)[\s:：]*([\d,]+)'),
      ],
      parser: (s) => int.tryParse(s?.replaceAll(',', '') ?? ''),
    );

    // 做种数
    info.seedingCount = _extractNumber(
      html,
      patterns: [
        RegExp(r'(?:做种|seeding|做种数)[\s:：]*(\d+)'),
      ],
      parser: (s) => int.tryParse(s ?? ''),
    );

    // 下载数
    info.leechingCount = _extractNumber(
      html,
      patterns: [
        RegExp(r'(?:下载中|leeching|下载数)[\s:：]*(\d+)'),
      ],
      parser: (s) => int.tryParse(s ?? ''),
    );

    info.lastFetchedAt = DateTime.now();
    info.fetchFailed = false;

    return info;
  }

  /// 从 HTML 中按多个正则模式依次尝试提取值
  T? _extractNumber<T>(
    String html, {
    required List<RegExp> patterns,
    required T? Function(String?) parser,
  }) {
    for (final p in patterns) {
      final m = p.firstMatch(html);
      if (m != null) {
        final result = parser(m.group(1));
        if (result != null) return result;
      }
    }
    return null;
  }

  /// 解析文件大小字符串（如 "1.23 TB", "500 GB"）为字节数
  static int? parseSize(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    s = s.trim().replaceAll(',', '');

    final units = {
      'TiB': 1099511627776,
      'GiB': 1073741824,
      'MiB': 1048576,
      'KiB': 1024,
      'TB': 1000000000000,
      'GB': 1000000000,
      'MB': 1000000,
      'KB': 1000,
      'B': 1,
    };

    for (final entry in units.entries) {
      if (s.endsWith(entry.key)) {
        final numStr = s.substring(0, s.length - entry.key.length).trim();
        final num = double.tryParse(numStr);
        if (num != null) return (num * entry.value).round();
        return null;
      }
    }

    return int.tryParse(s);
  }

  /// 解析分享率字符串
  static double? parseRatio(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    s = s.trim();
    if (s == '∞' || s == 'Inf.' || s == 'Infinity') return double.infinity;
    return double.tryParse(s);
  }
}
