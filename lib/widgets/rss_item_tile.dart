import 'package:flutter/material.dart';
import '../models/rss_source.dart';

class RssItemTile extends StatelessWidget {
  final RssItem item;
  final bool isSelected;
  final bool selectMode;
  final VoidCallback? onTap;

  const RssItemTile({
    super.key,
    required this.item,
    this.isSelected = false,
    this.selectMode = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = item.isDuplicate || item.isDownloaded;

    return ListTile(
      leading: selectMode
          ? Icon(isSelected ? Icons.check_box : Icons.check_box_outline_blank)
          : const Icon(Icons.article_outlined),
      title: Text(
        item.title,
        style: TextStyle(
          color: isDisabled ? Colors.grey : null,
          decoration: isDisabled ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(
        '${item.pubDate.toString().substring(0, 16)}${item.isDuplicate ? '  ·  已存在' : ''}${item.isDownloaded ? '  ·  已下载' : ''}',
        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
      ),
      enabled: !isDisabled,
      onTap: isDisabled ? null : onTap,
    );
  }
}
