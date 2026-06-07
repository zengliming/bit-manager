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
