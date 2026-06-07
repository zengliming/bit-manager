import 'package:xml/xml.dart';
import 'package:http/http.dart' as http;
import '../models/rss_source.dart';

class RssService {
  /// 从 RSS URL 获取并解析条目
  Future<List<RssItem>> fetchItems(RssSource source) async {
    try {
      final response = await http.get(Uri.parse(source.url));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      return _parseXml(response.body, source);
    } catch (e) {
      throw Exception('Failed to fetch RSS: $e');
    }
  }

  /// 解析 RSS XML
  List<RssItem> _parseXml(String xmlString, RssSource source) {
    final document = XmlDocument.parse(xmlString);
    final items = <RssItem>[];

    // 支持 RSS 2.0
    final rssItems = document.findAllElements('item');
    for (final item in rssItems) {
      final guid = item.findElements('guid').firstOrNull?.innerText ??
                   item.findElements('link').firstOrNull?.innerText ??
                   '';
      final title = item.findElements('title').firstOrNull?.innerText ?? '';
      final link = item.findElements('link').firstOrNull?.innerText;
      final category = item.findElements('category').firstOrNull?.innerText;
      final pubDateStr = item.findElements('pubDate').firstOrNull?.innerText;

      DateTime? pubDate;
      if (pubDateStr != null) {
        pubDate = DateTime.tryParse(pubDateStr);
        pubDate ??= _parseRfc2822(pubDateStr);
      }

      items.add(RssItem(
        guid: guid,
        title: title,
        link: link,
        category: category,
        pubDate: pubDate ?? DateTime.now(),
      ));
    }

    // 也尝试 Atom 格式
    if (items.isEmpty) {
      final atomEntries = document.findAllElements('entry');
      for (final entry in atomEntries) {
        final id = entry.findElements('id').firstOrNull?.innerText ?? '';
        final title = entry.findElements('title').firstOrNull?.innerText ?? '';
        final link = entry.findElements('link').firstOrNull?.getAttribute('href');
        final category = entry.findElements('category').firstOrNull?.getAttribute('term');
        final published = entry.findElements('published').firstOrNull?.innerText;

        items.add(RssItem(
          guid: id,
          title: title,
          link: link,
          category: category,
          pubDate: published != null ? DateTime.tryParse(published) ?? DateTime.now() : DateTime.now(),
        ));
      }
    }

    return items;
  }

  DateTime? _parseRfc2822(String input) {
    try {
      final cleaned = input.replaceAll(RegExp(r'\s+'), ' ').trim();
      final months = {
        'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
        'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
      };
      final parts = cleaned.split(' ');
      if (parts.length < 5) return null;

      final day = int.tryParse(parts[1]) ?? 1;
      final month = months[parts[2]] ?? 1;
      final year = int.tryParse(parts[3]) ?? DateTime.now().year;

      final timeParts = parts[4].split(':');
      final hour = int.tryParse(timeParts[0]) ?? 0;
      final minute = int.tryParse(timeParts[1]) ?? 0;
      final second = timeParts.length > 2 ? int.tryParse(timeParts[2]) ?? 0 : 0;

      return DateTime(year, month, day, hour, minute, second);
    } catch (_) {
      return null;
    }
  }

  /// 根据过滤正则检查标题是否匹配
  bool matchesFilter(String title, String? regex) {
    if (regex == null || regex.isEmpty) return true;
    try {
      return RegExp(regex, caseSensitive: false).hasMatch(title);
    } catch (_) {
      return true;
    }
  }
}
