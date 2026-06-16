import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';

import '../models/site_config.dart';
import '../providers/site_provider.dart';
import '../services/site_service.dart';

/// 站点解析规则编辑页
///
/// 让用户用 UI 配置 [SiteParseSchema.fields] —— 不用再去手写 JSON。
/// 支持：
/// - 增/删字段
/// - 编辑每个字段的 selector 列表（多个 selector 按顺序尝试）
/// - 选 attr（取属性而非文本）
/// - 配置 filter 链
/// - 用 dump 的 HTML 预览每个字段命中什么值
class SiteRulesScreen extends StatefulWidget {
  final SiteConfig site;

  const SiteRulesScreen({super.key, required this.site});

  @override
  State<SiteRulesScreen> createState() => _SiteRulesScreenState();
}

/// 已知字段的 label，按这个顺序展示 + 在「添加」面板里列出
const _fieldLabels = <String, String>{
  'name': '用户名',
  'id': '用户 ID',
  'levelName': '等级',
  'uploaded': '上传量',
  'downloaded': '下载量',
  'trueUploaded': '真实上传量',
  'trueDownloaded': '真实下载量',
  'ratio': '分享率',
  'bonus': '魔力值',
  'seedingBonus': '做种积分',
  'bonusPerHour': '时魔',
  'seeding': '当前做种',
  'seedingSize': '做种体积',
  'messageCount': '未读消息',
  'joinTime': '加入日期',
  'lastAccessAt': '最近动向',
  'hnrPreWarning': 'H&R 待考核',
  'hnrUnsatisfied': 'H&R 不达标',
};

const _availableFilters = <String>[
  'parseNumber',
  'parseSize',
  'parseTime',
  'trim',
  'split',
  'querystring',
  'regex',
];

class _SiteRulesScreenState extends State<SiteRulesScreen> {
  /// 工作副本，离开页面时保存才同步回 SiteProvider
  late Map<String, _EditableField> _fields;
  String? _detailsPath;

  /// 预览用 HTML（从 dump 文件加载或粘贴）
  final _previewCtrl = TextEditingController();
  Map<String, Object?>? _previewResults;
  String? _previewError;

  @override
  void initState() {
    super.initState();
    _detailsPath = widget.site.parseSchema?.userDetailsPath;
    _fields = {};
    final src = widget.site.parseSchema?.fields ?? const <String, FieldRule>{};
    src.forEach((k, v) {
      _fields[k] = _EditableField.from(v);
    });
  }

  @override
  void dispose() {
    _previewCtrl.dispose();
    for (final f in _fields.values) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.site.name} · 解析规则'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: '导入默认 NexusPHP 规则',
            onPressed: _importDefaults,
          ),
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: '保存',
            onPressed: _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '详情页路径',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    initialValue: _detailsPath ?? '',
                    decoration: const InputDecoration(
                      hintText: '默认 /userdetails.php',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) =>
                        _detailsPath = v.trim().isEmpty ? null : v.trim(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Card(
            color: scheme.tertiaryContainer.withValues(alpha: 0.3),
            child: const Padding(
              padding: EdgeInsets.all(10),
              child: Text(
                '提示：\n'
                '• 用户ID (id) 字段：必须把 attr 设为 href 并加 querystring filter 取参数 id，'
                '否则会把用户名塞进 ID 槽。\n'
                '• 等级 (levelName) 字段：通常 attr 设为 title（从 <img title="VIP"> 拿等级名）。\n'
                '• 数字类字段（bonus/uploaded 等）：加 parseNumber 或 parseSize filter，'
                'regex 链可从复杂文本里抠数字再转换。',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 字段列表
          ...(_fieldLabels.keys.where(_fields.containsKey).map((key) {
            return _FieldCard(
              fieldKey: key,
              label: _fieldLabels[key] ?? key,
              field: _fields[key]!,
              previewValue: _previewResults?[key],
              onDelete: () => setState(() {
                _fields.remove(key)?.dispose();
              }),
              onChanged: () => setState(() {
                // 用户编辑后清掉旧的预览
                _previewResults = null;
              }),
            );
          }).toList()),

          // 加字段
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('添加字段'),
            onPressed: _showAddFieldSheet,
          ),

          const SizedBox(height: 24),
          Card(
            color: scheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '预览 / 测试',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _loadDumpFromDisk,
                        child: const Text('从 dump 文件加载'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '粘贴 userdetails.php 的 HTML（或用左侧按钮从 dump 加载），点「测试」运行所有规则',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _previewCtrl,
                    maxLines: 6,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                    decoration: const InputDecoration(
                      hintText: '<html>...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: _runPreview,
                    child: const Text('测试当前规则'),
                  ),
                  if (_previewError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _previewError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showAddFieldSheet() {
    final available = _fieldLabels.keys
        .where((k) => !_fields.containsKey(k))
        .toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('所有已知字段都已添加')));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final key in available)
                ListTile(
                  title: Text(_fieldLabels[key] ?? key),
                  subtitle: Text(
                    key,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _fields[key] = _EditableField.empty();
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _importDefaults() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await SiteService.ensureDefaultSchemaLoaded();
      // 直接读 default_schema.json 把字段拷过来
      final raw = await rootBundle.loadString(
        'assets/sites/default_schema.json',
      );
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final fieldsJson = json['fields'] as Map<String, dynamic>?;
      if (fieldsJson == null) {
        messenger.showSnackBar(const SnackBar(content: Text('默认 schema 为空')));
        return;
      }
      int added = 0;
      fieldsJson.forEach((key, value) {
        if (key.startsWith('_') || value is! Map) return;
        if (_fields.containsKey(key)) return; // 不覆盖用户已配置
        try {
          final rule = FieldRule.fromJson(Map<String, dynamic>.from(value));
          _fields[key] = _EditableField.from(rule);
          added++;
        } catch (_) {}
      });
      setState(() {});
      messenger.showSnackBar(
        SnackBar(
          content: Text(added > 0 ? '已添加 $added 个默认字段' : '所有默认字段都已存在，未做改动'),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('导入失败：$e')));
    }
  }

  Future<void> _loadDumpFromDisk() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await SiteService.dumpPathFor(widget.site.id, 'detail');
      if (path == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('未找到 dump 文件 — 先刷新一次站点用户信息以生成')),
        );
        return;
      }
      final html = await SiteService.readDump(path);
      if (html == null || html.isEmpty) {
        messenger.showSnackBar(SnackBar(content: Text('dump 文件为空：$path')));
        return;
      }
      setState(() {
        _previewCtrl.text = html;
        _previewResults = null;
        _previewError = null;
      });
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('加载失败：$e')));
    }
  }

  Future<void> _runPreview() async {
    final html = _previewCtrl.text;
    if (html.trim().isEmpty) {
      setState(() {
        _previewError = '请先粘贴或加载 HTML';
        _previewResults = null;
      });
      return;
    }
    try {
      await SiteService.ensureDefaultSchemaLoaded();
      final rules = <String, FieldRule>{};
      _fields.forEach((k, ef) {
        final rule = ef.toRule();
        if (rule != null) rules[k] = rule;
      });
      // 直接调 SiteService 的字段执行器，不写 site 数据
      final results = SiteService.runFieldRulesForPreview(html, rules);
      setState(() {
        _previewResults = results;
        _previewError = null;
      });
    } catch (e) {
      setState(() {
        _previewError = '执行失败：$e';
        _previewResults = null;
      });
    }
  }

  Future<void> _save() async {
    // 验证字段：每条规则至少要有一个 selector
    for (final entry in _fields.entries) {
      final rule = entry.value.toRule();
      if (rule == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '字段 ${_fieldLabels[entry.key] ?? entry.key}：请至少填一个 selector',
            ),
          ),
        );
        return;
      }
    }

    final fields = <String, FieldRule>{};
    _fields.forEach((k, v) {
      final r = v.toRule();
      if (r != null) fields[k] = r;
    });

    final old = widget.site.parseSchema;
    final newSchema = SiteParseSchema(
      schema: old?.schema,
      userDetailsPath: _detailsPath,
      fields: fields.isEmpty ? null : fields,
      // 保留旧的 *Labels 兼容
      usernameLabels: old?.usernameLabels,
      levelLabels: old?.levelLabels,
      transferLabels: old?.transferLabels,
      bonusLabels: old?.bonusLabels,
      joinTimeLabels: old?.joinTimeLabels,
      seedingLabels: old?.seedingLabels,
      leechingLabels: old?.leechingLabels,
    );

    final updated = widget.site.copyWith(parseSchema: newSchema);
    await context.read<SiteProvider>().updateSite(widget.site.id, updated);
    if (!mounted) return;
    Navigator.pop(context);
  }
}

// ── 编辑态 ──

/// 一个 FieldRule 的可编辑形态：所有列表都用可变 controller，方便 UI 增删
class _EditableField {
  final List<TextEditingController> selectorCtrls;
  final TextEditingController attrCtrl;
  final List<_EditableFilter> filters;

  _EditableField({
    required this.selectorCtrls,
    required this.attrCtrl,
    required this.filters,
  });

  factory _EditableField.empty() => _EditableField(
    selectorCtrls: [TextEditingController()],
    attrCtrl: TextEditingController(),
    filters: [],
  );

  factory _EditableField.from(FieldRule rule) {
    final filters = <_EditableFilter>[];
    if (rule.filters != null) {
      for (final f in rule.filters!) {
        filters.add(_EditableFilter.from(f));
      }
    } else if (rule.filter != null) {
      filters.add(_EditableFilter.from(rule.filter!));
    }
    return _EditableField(
      selectorCtrls: (rule.selector.isEmpty
          ? <TextEditingController>[TextEditingController()]
          : rule.selector.map((s) => TextEditingController(text: s)).toList()),
      attrCtrl: TextEditingController(text: rule.attr ?? ''),
      filters: filters,
    );
  }

  void dispose() {
    for (final c in selectorCtrls) {
      c.dispose();
    }
    attrCtrl.dispose();
    for (final f in filters) {
      f.dispose();
    }
  }

  FieldRule? toRule() {
    final selectors = selectorCtrls
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (selectors.isEmpty) return null;
    final attr = attrCtrl.text.trim();
    final filterList = <Object>[];
    for (final f in filters) {
      final v = f.toFilter();
      if (v != null) filterList.add(v);
    }
    return FieldRule(
      selector: selectors,
      attr: attr.isEmpty ? null : attr,
      filter: filterList.length == 1 ? filterList.first : null,
      filters: filterList.length > 1 ? filterList : null,
    );
  }
}

/// 一个 filter 描述符的可编辑形态
class _EditableFilter {
  String name;
  final List<TextEditingController> argCtrls;

  _EditableFilter({required this.name, required this.argCtrls});

  factory _EditableFilter.from(Object descriptor) {
    if (descriptor is String) {
      return _EditableFilter(name: descriptor, argCtrls: []);
    }
    if (descriptor is Map) {
      final name = (descriptor['name'] as String?) ?? 'parseNumber';
      final args = (descriptor['args'] as List?) ?? const [];
      return _EditableFilter(
        name: name,
        argCtrls: args
            .map((a) => TextEditingController(text: a.toString()))
            .toList(),
      );
    }
    return _EditableFilter(name: 'parseNumber', argCtrls: []);
  }

  void dispose() {
    for (final c in argCtrls) {
      c.dispose();
    }
  }

  /// 是否需要参数（regex / split / querystring 必须有）
  bool get needsArgs =>
      name == 'regex' || name == 'split' || name == 'querystring';

  Object? toFilter() {
    if (argCtrls.isEmpty) return name;
    final args = argCtrls
        .map((c) => c.text)
        .where((s) => s.isNotEmpty)
        .map<Object>((s) {
          // 简单类型推断：纯整数 → int，"true/false" → bool，否则 String
          final i = int.tryParse(s);
          if (i != null) return i;
          if (s == 'true') return true;
          if (s == 'false') return false;
          return s;
        })
        .toList();
    if (args.isEmpty) return name;
    return {'name': name, 'args': args};
  }
}

// ── UI 组件 ──

class _FieldCard extends StatefulWidget {
  final String fieldKey;
  final String label;
  final _EditableField field;
  final Object? previewValue;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const _FieldCard({
    required this.fieldKey,
    required this.label,
    required this.field,
    required this.previewValue,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  State<_FieldCard> createState() => _FieldCardState();
}

class _FieldCardState extends State<_FieldCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = widget.previewValue;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头部：label + 预览结果 + 折叠/删除
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Row(
                      children: [
                        Icon(
                          _expanded ? Icons.expand_less : Icons.expand_more,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '(${widget.fieldKey})',
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (preview != null)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        preview.toString(),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.red,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onDelete,
                ),
              ],
            ),
            if (_expanded) ...[
              const Divider(height: 16),
              const Text(
                'Selectors（按顺序尝试，首个非空者胜）',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              for (var i = 0; i < widget.field.selectorCtrls.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: widget.field.selectorCtrls[i],
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                            hintText: "td.rowhead:contains('xxx') + td",
                          ),
                          onChanged: (_) => widget.onChanged(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 18),
                        visualDensity: VisualDensity.compact,
                        onPressed: widget.field.selectorCtrls.length == 1
                            ? null
                            : () => setState(() {
                                widget.field.selectorCtrls
                                    .removeAt(i)
                                    .dispose();
                                widget.onChanged();
                              }),
                      ),
                    ],
                  ),
                ),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('加 selector', style: TextStyle(fontSize: 12)),
                onPressed: () => setState(() {
                  widget.field.selectorCtrls.add(TextEditingController());
                  widget.onChanged();
                }),
              ),
              const SizedBox(height: 4),

              // attr
              Row(
                children: [
                  const SizedBox(
                    width: 80,
                    child: Text(
                      'Attr',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: widget.field.attrCtrl,
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        hintText: '空 = 取文本；title / alt / href ...',
                      ),
                      onChanged: (_) => widget.onChanged(),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Text(
                'Filters（顺序应用）',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              for (var i = 0; i < widget.field.filters.length; i++)
                _FilterRow(
                  filter: widget.field.filters[i],
                  onDelete: () => setState(() {
                    widget.field.filters.removeAt(i).dispose();
                    widget.onChanged();
                  }),
                  onChanged: widget.onChanged,
                ),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('加 filter', style: TextStyle(fontSize: 12)),
                onPressed: () => setState(() {
                  widget.field.filters.add(
                    _EditableFilter(name: 'parseNumber', argCtrls: []),
                  );
                  widget.onChanged();
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatefulWidget {
  final _EditableFilter filter;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const _FilterRow({
    required this.filter,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  State<_FilterRow> createState() => _FilterRowState();
}

class _FilterRowState extends State<_FilterRow> {
  @override
  Widget build(BuildContext context) {
    final f = widget.filter;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButton<String>(
            value: f.name,
            items: _availableFilters
                .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                f.name = v;
                // 切换 filter 时调整 args 数量
                if (v == 'regex' && f.argCtrls.isEmpty) {
                  f.argCtrls.add(TextEditingController());
                } else if (v == 'split' && f.argCtrls.length < 2) {
                  while (f.argCtrls.length < 2) {
                    f.argCtrls.add(TextEditingController());
                  }
                } else if (v == 'querystring' && f.argCtrls.isEmpty) {
                  f.argCtrls.add(TextEditingController());
                } else if (!f.needsArgs && f.argCtrls.isNotEmpty) {
                  for (final c in f.argCtrls) {
                    c.dispose();
                  }
                  f.argCtrls.clear();
                }
                widget.onChanged();
              });
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < f.argCtrls.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: TextField(
                      controller: f.argCtrls[i],
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        border: const OutlineInputBorder(),
                        hintText: _argHint(f.name, i),
                      ),
                      onChanged: (_) => widget.onChanged(),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.remove_circle_outline,
              size: 18,
              color: Colors.red,
            ),
            visualDensity: VisualDensity.compact,
            onPressed: widget.onDelete,
          ),
        ],
      ),
    );
  }

  String _argHint(String name, int idx) {
    switch (name) {
      case 'regex':
        return idx == 0 ? '正则 pattern' : '标志（"i" 等）';
      case 'split':
        return idx == 0 ? '分隔符' : '取第几段（0 起）';
      case 'querystring':
        return idx == 0 ? '参数名（如 id）' : '';
      default:
        return '';
    }
  }
}
