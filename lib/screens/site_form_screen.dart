import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/site_config.dart';
import '../providers/site_provider.dart';

class SiteFormScreen extends StatefulWidget {
  final SiteConfig? site;
  const SiteFormScreen({super.key, this.site});

  @override
  State<SiteFormScreen> createState() => _SiteFormScreenState();
}

class _SiteFormScreenState extends State<SiteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _tagsCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _idCtrl;

  bool get isEditing => widget.site != null;

  @override
  void initState() {
    super.initState();
    final s = widget.site;
    _idCtrl = TextEditingController(text: s?.id ?? '');
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _urlCtrl = TextEditingController(text: s?.baseUrl ?? '');
    _tagsCtrl = TextEditingController(text: s?.tags.join(', ') ?? '');
    _notesCtrl = TextEditingController(text: s?.notes ?? '');
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _tagsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? '编辑站点' : '添加站点')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ID（仅新建时可编辑）
              if (!isEditing)
                TextFormField(
                  controller: _idCtrl,
                  decoration: const InputDecoration(
                    labelText: '站点标识',
                    hintText: '唯一标识，如 m-team',
                    helperText: '仅支持小写字母、数字和连字符',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return '请输入站点标识';
                    if (!RegExp(r'^[a-z0-9-]+$').hasMatch(v.trim())) {
                      return '仅支持小写字母、数字和连字符';
                    }
                    return null;
                  },
                ),
              if (!isEditing) const SizedBox(height: 16),

              TextFormField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '名称',
                  hintText: '例如: M-Team',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? '请输入名称' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _urlCtrl,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: '站点 URL',
                  hintText: 'https://example.com',
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _tagsCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '标签',
                  hintText: '电影, 官组, 综合',
                  helperText: '用逗号分隔多个标签',
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '备注（可选）',
                  hintText: '添加一些备注信息...',
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: Text(isEditing ? '保存' : '添加'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<SiteProvider>();
    final id = widget.site?.id ?? _idCtrl.text.trim();
    final tags = _tagsCtrl.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    final config = SiteConfig(
      id: id,
      name: _nameCtrl.text.trim(),
      baseUrl: _urlCtrl.text.trim().isEmpty ? null : _urlCtrl.text.trim(),
      tags: tags,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      sortOrder: widget.site?.sortOrder ?? 0,
      addedAt: widget.site?.addedAt,
    );

    if (isEditing) {
      await provider.updateSite(widget.site!.id, config);
    } else {
      await provider.addSite(config);
    }

    if (mounted) Navigator.pop(context);
  }
}
