import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/site_config.dart';
import '../providers/site_provider.dart';
import '../widgets/site_favicon.dart';
import 'site_form_screen.dart';

class SiteImportScreen extends StatefulWidget {
  const SiteImportScreen({super.key});

  @override
  State<SiteImportScreen> createState() => _SiteImportScreenState();
}

class _SiteImportScreenState extends State<SiteImportScreen> {
  List<SitePreset> _allPresets = [];
  List<SitePreset> _filteredPresets = [];
  final _selectedIds = <String>{};
  final _searchCtrl = TextEditingController();
  String? _categoryFilter;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPresets();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPresets() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/sites/presets.json');
      final list = jsonDecode(jsonStr) as List;
      _allPresets = list
          .map((j) => SitePreset.fromJson(j as Map<String, dynamic>))
          .toList();
      _applyFilters();
    } catch (_) {
      // 预设加载失败
    } finally {
      setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    var result = _allPresets;

    if (_searchCtrl.text.isNotEmpty) {
      final q = _searchCtrl.text.toLowerCase();
      result = result
          .where(
            (p) =>
                p.name.toLowerCase().contains(q) ||
                p.id.toLowerCase().contains(q) ||
                p.tags.any((t) => t.toLowerCase().contains(q)) ||
                p.aka.any((a) => a.toLowerCase().contains(q)),
          )
          .toList();
    }

    if (_categoryFilter != null) {
      result = result.where((p) => p.category == _categoryFilter).toList();
    }

    setState(() => _filteredPresets = result);
  }

  Set<String> get _categories {
    final cats = <String>{};
    for (final p in _allPresets) {
      if (p.category != null) cats.add(p.category!);
    }
    // Sort with common categories first
    final sorted = cats.toList()..sort();
    return sorted.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SiteProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('导入站点预设')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 搜索栏
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: const InputDecoration(
                      hintText: '搜索站点名称、别名或标签...',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (_) => _applyFilters(),
                  ),
                ),
                // 分类筛选
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _categories.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return FilterChip(
                          label: const Text('全部'),
                          selected: _categoryFilter == null,
                          onSelected: (_) {
                            _categoryFilter = null;
                            _applyFilters();
                          },
                          visualDensity: VisualDensity.compact,
                        );
                      }
                      final cat = _categories.elementAt(index - 1);
                      return FilterChip(
                        label: Text(cat),
                        selected: _categoryFilter == cat,
                        onSelected: (_) {
                          _categoryFilter = _categoryFilter == cat ? null : cat;
                          _applyFilters();
                        },
                        visualDensity: VisualDensity.compact,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                // 统计
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        '共 ${_filteredPresets.length} 个站点',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '已选 ${_selectedIds.length} 个',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // 预设列表
                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredPresets.length,
                    itemBuilder: (context, index) {
                      final preset = _filteredPresets[index];
                      final isImported = provider.isSiteImported(preset.id);
                      final isSelected = _selectedIds.contains(preset.id);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: SiteFavicon(
                            iconAsset: preset.iconAsset,
                            siteName: preset.name,
                            size: 40,
                            radius: 8,
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  preset.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isImported
                                        ? Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant
                                        : null,
                                  ),
                                ),
                              ),
                              if (preset.aka.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    preset.aka.join(' / '),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (preset.description != null &&
                                  preset.description!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    preset.description!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Wrap(
                                  spacing: 4,
                                  children: [
                                    if (preset.category != null)
                                      _infoChip(
                                        context,
                                        preset.category!,
                                        false,
                                      ),
                                    if (preset.baseUrl != null)
                                      _infoChip(
                                        context,
                                        _hostFromUrl(preset.baseUrl!),
                                        true,
                                      ),
                                    if (preset.tags.isNotEmpty)
                                      ...preset.tags
                                          .take(3)
                                          .map(
                                            (t) => _infoChip(context, t, false),
                                          ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isImported)
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                  ),
                                  tooltip: '编辑后添加',
                                  onPressed: () => _editAndAdd(preset),
                                ),
                              if (isImported)
                                Icon(
                                  Icons.check_circle,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              else
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (_) {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedIds.remove(preset.id);
                                      } else {
                                        _selectedIds.add(preset.id);
                                      }
                                    });
                                  },
                                ),
                            ],
                          ),
                          onTap: isImported
                              ? null
                              : () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedIds.remove(preset.id);
                                    } else {
                                      _selectedIds.add(preset.id);
                                    }
                                  });
                                },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _selectedIds.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: () => _importSelected(provider),
                  child: Text('导入选中 (${_selectedIds.length})'),
                ),
              ),
            )
          : null,
    );
  }

  Widget _infoChip(BuildContext context, String text, bool isUrl) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: isUrl
            ? const Color(0xFF007AFF).withValues(alpha: 0.08)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: isUrl
              ? const Color(0xFF007AFF)
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  String _hostFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (_) {
      return url;
    }
  }

  Future<void> _editAndAdd(SitePreset preset) async {
    // 跳转到编辑表单，预填预设数据
    final config = SiteConfig(
      id: preset.id,
      name: preset.name,
      baseUrl: preset.baseUrl,
      tags: List.from(preset.tags),
    );
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => SiteFormScreen(site: config)),
    );
    if (result == true && mounted) {
      setState(() {}); // refresh import status
    }
  }

  Future<void> _importSelected(SiteProvider provider) async {
    final selectedPresets = _allPresets
        .where((p) => _selectedIds.contains(p.id))
        .toList();
    final count = await provider.importPresets(selectedPresets);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('成功导入 $count 个站点')));
      setState(() => _selectedIds.clear());
    }
  }
}
