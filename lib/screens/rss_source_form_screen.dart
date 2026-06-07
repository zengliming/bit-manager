import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/rss_source.dart';
import '../providers/rss_provider.dart';
import '../providers/client_provider.dart';

class RssSourceFormScreen extends StatefulWidget {
  final RssSource? source;
  const RssSourceFormScreen({super.key, this.source});

  @override
  State<RssSourceFormScreen> createState() => _RssSourceFormScreenState();
}

class _RssSourceFormScreenState extends State<RssSourceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _filterCtrl;
  late bool _autoDownload;
  late String? _assignedClientId;
  late int _refreshInterval;

  bool get isEditing => widget.source != null;

  @override
  void initState() {
    super.initState();
    final s = widget.source;
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _urlCtrl = TextEditingController(text: s?.url ?? '');
    _filterCtrl = TextEditingController(text: s?.filterRegex ?? '');
    _autoDownload = s?.autoDownload ?? false;
    _assignedClientId = s?.assignedClientId;
    _refreshInterval = s?.refreshIntervalMinutes ?? 15;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _filterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? '编辑订阅源' : '添加订阅源')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: '名称', hintText: '例如: 动漫花园'),
              validator: (v) => (v == null || v.trim().isEmpty) ? '请输入名称' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _urlCtrl,
              decoration: const InputDecoration(labelText: 'RSS 地址'),
              validator: (v) => (v == null || v.trim().isEmpty) ? '请输入 RSS 地址' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _filterCtrl,
              decoration: const InputDecoration(
                labelText: '过滤规则（可选）',
                hintText: '例如: 1080p|4K.*CHS',
                helperText: '正则表达式，匹配标题',
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('自动下载'),
              subtitle: const Text('匹配规则后自动添加到客户端'),
              value: _autoDownload,
              onChanged: (v) => setState(() => _autoDownload = v),
            ),
            if (_autoDownload) ...[
              const SizedBox(height: 8),
              Consumer<ClientProvider>(
                builder: (context, cp, _) => DropdownButtonFormField<String>(
                  initialValue: _assignedClientId,
                  decoration: const InputDecoration(labelText: '目标客户端'),
                  items: cp.clients.where((c) => c.isActive).map((c) =>
                    DropdownMenuItem(value: c.id, child: Text(c.name))
                  ).toList(),
                  onChanged: (v) => _assignedClientId = v,
                  validator: (v) => _autoDownload && v == null ? '请选择客户端' : null,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _refreshInterval,
                decoration: const InputDecoration(labelText: '刷新间隔（分钟）'),
                items: [5, 10, 15, 30, 60].map((m) =>
                  DropdownMenuItem(value: m, child: Text('$m 分钟'))
                ).toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _refreshInterval = v);
                },
              ),
            ],
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _submit,
              child: Text(isEditing ? '保存' : '添加'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<RssProvider>();
    final source = RssSource(
      id: widget.source?.id ?? const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      url: _urlCtrl.text.trim(),
      filterRegex: _filterCtrl.text.trim().isEmpty ? null : _filterCtrl.text.trim(),
      autoDownload: _autoDownload,
      assignedClientId: _assignedClientId,
      refreshIntervalMinutes: _refreshInterval,
    );

    if (isEditing) {
      await provider.updateSource(widget.source!.id, source);
    } else {
      await provider.addSource(source);
    }

    if (mounted) Navigator.pop(context);
  }
}
