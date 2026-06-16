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

  // 解析覆写：用逗号分隔的标签词，对应 td.rowhead 单元格内文本
  late final TextEditingController _bonusLabelsCtrl;
  late final TextEditingController _levelLabelsCtrl;
  late final TextEditingController _userDetailsPathCtrl;
  // 站点架构：null = 自动（NexusPHP），显式选 NexusPHP/Gazelle
  String? _schema;
  bool _advancedExpanded = false;

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

    final schema = s?.parseSchema;
    _bonusLabelsCtrl = TextEditingController(
        text: schema?.bonusLabels?.join(', ') ?? '');
    _levelLabelsCtrl = TextEditingController(
        text: schema?.levelLabels?.join(', ') ?? '');
    _userDetailsPathCtrl =
        TextEditingController(text: schema?.userDetailsPath ?? '');
    _schema = schema?.schema;
    _advancedExpanded = schema != null;
  }

  @override
  void dispose() {
    _idCtrl.dispose();
    _nameCtrl.dispose();
    _urlCtrl.dispose();
    _tagsCtrl.dispose();
    _notesCtrl.dispose();
    _bonusLabelsCtrl.dispose();
    _levelLabelsCtrl.dispose();
    _userDetailsPathCtrl.dispose();
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
              const SizedBox(height: 16),

              // ── 高级：解析覆写（NexusPHP 二开站点适配）──
              ExpansionTile(
                title: const Text('高级：解析配置'),
                subtitle: const Text(
                    '建议去详情页用「解析规则」编辑器（更强大）。下方是旧版仅覆写标签词'),
                initiallyExpanded: _advancedExpanded,
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  TextFormField(
                    controller: _bonusLabelsCtrl,
                    decoration: const InputDecoration(
                      labelText: '魔力值标签词',
                      hintText: '啤酒瓶, 喵饼, 蝌蚪 ...',
                      helperText: '用逗号分隔。默认已识别"魔力值/Karma Points/Bonus"等',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _levelLabelsCtrl,
                    decoration: const InputDecoration(
                      labelText: '等级标签词',
                      hintText: '默认为"等级/等級/Class"',
                      helperText: '可选；只有用别名的站点才需填写',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _userDetailsPathCtrl,
                    decoration: const InputDecoration(
                      labelText: '用户详情页路径',
                      hintText: '/userdetails.php',
                      helperText: '默认为 /userdetails.php，仅二开站点改路径时填',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: _schema,
                    decoration: const InputDecoration(
                      labelText: '站点架构',
                      helperText: '默认 NexusPHP。Gazelle 站点选 Gazelle。',
                    ),
                    items: const [
                      DropdownMenuItem<String?>(
                          value: null, child: Text('自动（NexusPHP）')),
                      DropdownMenuItem<String?>(
                          value: 'NexusPHP', child: Text('NexusPHP')),
                      DropdownMenuItem<String?>(
                          value: 'Gazelle', child: Text('Gazelle')),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _schema = v;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

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

    // 解析覆写：把逗号分隔的字符串拆成 List；全空则置 null
    List<String>? splitLabels(TextEditingController c) {
      final list = c.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      return list.isEmpty ? null : list;
    }

    final bonusLabels = splitLabels(_bonusLabelsCtrl);
    final levelLabels = splitLabels(_levelLabelsCtrl);
    final detailsPath = _userDetailsPathCtrl.text.trim();
    final hasSchema = bonusLabels != null ||
        levelLabels != null ||
        detailsPath.isNotEmpty ||
        _schema != null;
    final schema = hasSchema
        ? SiteParseSchema(
            schema: _schema,
            bonusLabels: bonusLabels,
            levelLabels: levelLabels,
            userDetailsPath: detailsPath.isEmpty ? null : detailsPath,
          )
        : null;

    final config = SiteConfig(
      id: id,
      name: _nameCtrl.text.trim(),
      baseUrl: _urlCtrl.text.trim().isEmpty ? null : _urlCtrl.text.trim(),
      tags: tags,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      sortOrder: widget.site?.sortOrder ?? 0,
      addedAt: widget.site?.addedAt,
      parseSchema: schema,
    );

    if (isEditing) {
      await provider.updateSite(widget.site!.id, config);
    } else {
      await provider.addSite(config);
    }

    if (mounted) Navigator.pop(context);
  }
}
