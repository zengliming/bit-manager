import 'package:intl/intl.dart';

String formatBytes(int bytes, {int decimals = 2}) {
  if (bytes <= 0) return '0 B';
  const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
  final i = (bytes.bitLength / 10).floor().clamp(0, suffixes.length - 1);
  final value = bytes / (1 << (i * 10));
  return '${value.toStringAsFixed(decimals)} ${suffixes[i]}';
}

String formatSpeed(int bytesPerSecond) => '${formatBytes(bytesPerSecond)}/s';

String formatPercent(double value) => '${(value * 100).toStringAsFixed(1)}%';

String formatDateTime(DateTime? dt, {String pattern = 'yyyy-MM-dd HH:mm'}) {
  if (dt == null) return '-';
  return DateFormat(pattern).format(dt);
}

String formatEta(int seconds) {
  if (seconds <= 0) return '--';
  final d = seconds ~/ 86400;
  final h = (seconds % 86400) ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (d > 0) return '${d}d ${h}h';
  if (h > 0) return '${h}h ${m}m';
  return '${m}m ${seconds % 60}s';
}

String formatRatio(double ratio) => ratio.toStringAsFixed(2);

/// 从 tracker URL 中提取站点名称
/// 取注册域名的主要部分（倒数第二段），跳过常见子域名前缀
/// 例如 "https://tracker.m-team.cc/announce" → "m-team"
/// 例如 "https://cdn.hdtime.org/announce" → "hdtime"
/// 例如 "https://192.168.1.1/announce" → "192.168.1.1"
String extractSiteFromUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  try {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasAuthority) return '';
    final host = uri.host;
    // IP 地址直接返回
    if (RegExp(r'^\d+(\.\d+){3}$').hasMatch(host)) return host;
    final parts = host.split('.');
    if (parts.length < 2) return parts[0];
    // 已知 TLD 列表（双段后缀），需要跳过这些才能拿到注册域名主体
    const compoundTlds = {
      'co.uk',
      'com.cn',
      'net.cn',
      'org.cn',
      'gov.cn',
      'co.jp',
      'com.hk',
      'com.tw',
    };
    String getEffectiveTld(String lastTwo) =>
        compoundTlds.contains(lastTwo) ? lastTwo : parts.last;
    // 跳过常见子域名前缀
    const skipPrefixes = {
      'tracker',
      'trackers',
      'www',
      'rss',
      'api',
      'cdn',
      'tr',
      'bt',
      'pt',
      'passport',
      'login',
    };
    // 从右往左跳过 TLD 和子域名前缀，取第一个非前缀的段
    final tld = getEffectiveTld(
      parts.length >= 2
          ? '${parts[parts.length - 2]}.${parts[parts.length - 1]}'
          : parts.last,
    );
    // 收集非 TLD 部分（去掉末尾的 TLD 段）
    final stem = parts.sublist(0, parts.length - tld.split('.').length);
    if (stem.isEmpty) return parts[parts.length - 2];
    for (final part in stem) {
      if (!skipPrefixes.contains(part.toLowerCase())) {
        return part;
      }
    }
    return stem.first;
  } catch (_) {
    return '';
  }
}
