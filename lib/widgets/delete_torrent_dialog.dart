import 'package:flutter/material.dart';

/// 删除种子确认框的返回结果
class DeleteTorrentResult {
  /// 用户是否确认删除
  final bool confirmed;

  /// 是否启用「无辅种时删除文件」
  final bool deleteFilesWhenNoCrossSeed;

  const DeleteTorrentResult({
    required this.confirmed,
    required this.deleteFilesWhenNoCrossSeed,
  });

  /// 用户取消
  static const cancelled = DeleteTorrentResult(
    confirmed: false,
    deleteFilesWhenNoCrossSeed: false,
  );
}

/// 弹出删除种子确认框，带「无辅种时删除文件」选项。
///
/// - [count]：待删种子总数。
/// - [willDeleteFilesCount]：勾选「无辅种时删除文件」后，会被删除数据文件的
///   种子数（即无辅种、删后无人引用其数据的种子数）。用于在勾选时提示用户
///   实际会删多少文件，避免误以为有辅种也会被删。
///
/// 返回 [DeleteTorrentResult.cancelled] 表示用户取消。
Future<DeleteTorrentResult> showDeleteTorrentDialog(
  BuildContext context, {
  required int count,
  required int willDeleteFilesCount,
}) async {
  bool deleteFilesWhenNoCrossSeed = false;
  final result = await showDialog<DeleteTorrentResult>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        final theme = Theme.of(ctx);
        // 勾选后的提示文案：说明实际会删多少个种子的文件，以及有辅种的保留文件
        String hint;
        if (deleteFilesWhenNoCrossSeed) {
          if (willDeleteFilesCount == 0) {
            hint = '选中的种子均有辅种，不会删除任何数据文件。';
          } else {
            hint = '将删除 $willDeleteFilesCount 个无辅种种子的数据文件；'
                '有辅种的种子仅移除任务、保留文件。';
          }
        } else {
          hint = '仅从客户端移除种子，保留已下载的数据文件。';
        }

        return AlertDialog(
          title: const Text('删除种子'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('确定要删除选中的 $count 个种子吗？'),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => setDialogState(
                  () => deleteFilesWhenNoCrossSeed =
                      !deleteFilesWhenNoCrossSeed,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Checkbox(
                        value: deleteFilesWhenNoCrossSeed,
                        onChanged: (v) => setDialogState(
                          () => deleteFilesWhenNoCrossSeed = v ?? false,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          '无辅种时删除文件',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  hint,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, DeleteTorrentResult.cancelled),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                ctx,
                DeleteTorrentResult(
                  confirmed: true,
                  deleteFilesWhenNoCrossSeed: deleteFilesWhenNoCrossSeed,
                ),
              ),
              child: const Text('删除', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    ),
  );
  return result ?? DeleteTorrentResult.cancelled;
}
