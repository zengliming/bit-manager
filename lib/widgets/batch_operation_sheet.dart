import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/client_config.dart';
import '../providers/client_provider.dart';
import '../providers/torrent_provider.dart';
import 'delete_torrent_dialog.dart';

/// 弹出批量操作面板。仅在选中至少 1 个种子时调用。
void showBatchOperationSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetCtx) => const _BatchOperationSheet(),
  );
}

class _BatchOperationSheet extends StatelessWidget {
  const _BatchOperationSheet();

  @override
  Widget build(BuildContext context) {
    final tp = context.read<TorrentProvider>();
    final count = tp.selectedCount;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '批量操作 · 已选 $count 个',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.pause),
            title: const Text('暂停选中'),
            onTap: () => _runAction(context, 'pause'),
          ),
          ListTile(
            leading: const Icon(Icons.play_arrow),
            title: const Text('恢复选中'),
            onTap: () => _runAction(context, 'resume'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('删除选中', style: TextStyle(color: Colors.red)),
            onTap: () => _runDelete(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.add_link),
            title: const Text('添加 Tracker'),
            onTap: () => _addTrackers(context),
          ),
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: const Text('替换 Tracker'),
            onTap: () => _replaceTrackers(context),
          ),
          ListTile(
            leading: const Icon(Icons.link_off),
            title: const Text('删除 Tracker'),
            onTap: () => _removeTrackers(context),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// 按 clientId 分组选中种子，返回 (client, hashes) 列表
  List<(ClientConfig, List<String>)> _groupedByClient(
    TorrentProvider tp,
    ClientProvider cp,
  ) {
    final selected = tp.selectedHashes.toSet();
    final out = <(ClientConfig, List<String>)>[];
    for (final client in cp.activeClients) {
      final hashes = tp.allTorrents
          .where((t) => selected.contains(t.hash) && t.clientId == client.id)
          .map((t) => t.hash)
          .toList();
      if (hashes.isNotEmpty) out.add((client, hashes));
    }
    return out;
  }

  Future<void> _runAction(BuildContext context, String action) async {
    Navigator.pop(context);
    final tp = context.read<TorrentProvider>();
    final cp = context.read<ClientProvider>();
    final groups = _groupedByClient(tp, cp);
    final messenger = ScaffoldMessenger.of(context);

    final failed = <String>[];
    for (final (client, hashes) in groups) {
      bool ok;
      if (action == 'resume') {
        ok = await tp.resumeTorrents(client, hashes);
      } else {
        ok = await tp.pauseTorrents(client, hashes);
      }
      if (!ok) failed.add(client.name);
    }
    tp.exitSelectMode();
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failed.isEmpty ? '操作成功' : '部分失败：${failed.join('、')}',
        ),
      ),
    );
  }

  Future<void> _runDelete(BuildContext context) async {
    final tp = context.read<TorrentProvider>();
    final cp = context.read<ClientProvider>();
    final selected = tp.selectedHashes.toList();
    final groups = _groupedByClient(tp, cp);

    int willDeleteFiles = 0;
    for (final (client, hashes) in groups) {
      willDeleteFiles +=
          tp.planSmartDelete(client, hashes).deleteFilesHashes.length;
    }

    final result = await showDeleteTorrentDialog(
      context,
      count: selected.length,
      willDeleteFilesCount: willDeleteFiles,
    );
    if (!result.confirmed) {
      if (context.mounted) Navigator.pop(context);
      return;
    }
    if (!context.mounted) return;
    Navigator.pop(context); // 关闭面板

    final messenger = ScaffoldMessenger.of(context);
    final failed = <String>[];
    for (final (client, hashes) in groups) {
      final ok = await tp.deleteTorrentsSmart(
        client,
        hashes,
        deleteFilesWhenNoCrossSeed: result.deleteFilesWhenNoCrossSeed,
      );
      if (!ok) failed.add(client.name);
    }
    tp.exitSelectMode();
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failed.isEmpty ? '已删除' : '部分失败：${failed.join('、')}',
        ),
      ),
    );
  }

  Future<void> _addTrackers(BuildContext context) async {
    final ctrl = TextEditingController();
    final urls = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('添加 Tracker'),
        content: TextField(
          controller: ctrl,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: '每行一个 Tracker URL',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('添加'),
          ),
        ],
      ),
    );
    if (urls == null || !context.mounted) return;

    final list = urls
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (list.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('未输入 Tracker URL')));
      return;
    }
    final invalid = list.where((u) => !u.contains('://')).toList();
    if (invalid.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tracker URL 格式异常（需含 ://）')),
      );
      return;
    }
    await _runTracker(
      context,
      (client, hashes) =>
          context.read<TorrentProvider>().addTrackers(client, hashes, list),
    );
  }

  Future<void> _replaceTrackers(BuildContext context) async {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('替换 Tracker'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldCtrl,
              decoration: const InputDecoration(
                labelText: '旧 Tracker URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newCtrl,
              decoration: const InputDecoration(
                labelText: '新 Tracker URL',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('替换'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final oldUrl = oldCtrl.text.trim();
    final newUrl = newCtrl.text.trim();
    if (oldUrl.isEmpty || newUrl.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('URL 不能为空')));
      return;
    }
    if (!oldUrl.contains('://') || !newUrl.contains('://')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tracker URL 格式异常（需含 ://）')),
      );
      return;
    }
    await _runTracker(
      context,
      (client, hashes) => context
          .read<TorrentProvider>()
          .replaceTrackers(client, hashes, oldUrl, newUrl),
    );
  }

  Future<void> _removeTrackers(BuildContext context) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除 Tracker'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: '要删除的 Tracker URL',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final url = ctrl.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('URL 不能为空')));
      return;
    }
    await _runTracker(
      context,
      (client, hashes) =>
          context.read<TorrentProvider>().removeTrackers(client, hashes, url),
    );
  }

  /// 执行 Tracker 操作的通用流程：逐客户端调用，汇总失败，SnackBar 反馈。
  /// Tracker 操作后不退出选择模式、不刷新列表。
  Future<void> _runTracker(
    BuildContext context,
    Future<bool> Function(ClientConfig client, List<String> hashes) action,
  ) async {
    Navigator.pop(context); // 关闭面板
    final tp = context.read<TorrentProvider>();
    final cp = context.read<ClientProvider>();
    final groups = _groupedByClient(tp, cp);
    final messenger = ScaffoldMessenger.of(context);

    final failed = <String>[];
    for (final (client, hashes) in groups) {
      final ok = await action(client, hashes);
      if (!ok) failed.add(client.name);
    }
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failed.isEmpty ? 'Tracker 操作完成' : '部分失败：${failed.join('、')}',
        ),
      ),
    );
  }
}
