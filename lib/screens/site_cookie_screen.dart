import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../models/site_config.dart';
import '../providers/site_provider.dart';

class SiteCookieScreen extends StatefulWidget {
  final SiteConfig site;

  const SiteCookieScreen({super.key, required this.site});

  @override
  State<SiteCookieScreen> createState() => _SiteCookieScreenState();
}

class _SiteCookieScreenState extends State<SiteCookieScreen> {
  final _cookieCtrl = TextEditingController();
  bool _webViewVisible = false;
  WebViewController? _webViewCtrl;

  SiteConfig get site => widget.site;

  @override
  void initState() {
    super.initState();
    final provider = context.read<SiteProvider>();
    final existing = provider.getCookieString(site.id);
    if (existing != null) {
      _cookieCtrl.text = existing;
    }
  }

  @override
  void dispose() {
    _cookieCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SiteProvider>();
    final hasCookie = provider.hasCookie(site.id);

    return Scaffold(
      appBar: AppBar(title: Text('${site.name} · Cookie')),
      body: _webViewVisible ? _buildWebView() : _buildForm(provider, hasCookie),
    );
  }

  Widget _buildForm(SiteProvider provider, bool hasCookie) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 状态卡片
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      hasCookie ? Icons.check_circle : Icons.info_outline,
                      color: hasCookie ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      hasCookie ? 'Cookie 已配置' : '未配置 Cookie',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (hasCookie) ...[
                  const SizedBox(height: 8),
                  Text(
                    '配置 Cookie 后可以抓取该站点的用户信息',
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // 方式一：手动录入
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '手动录入 Cookie',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '从浏览器 DevTools 复制完整的 Cookie 字符串粘贴到下方',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _cookieCtrl,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'uid=123; pass=abc; ...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => _saveManualCookie(provider),
                  child: const Text('保存 Cookie'),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 方式二：WebView 登录
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '通过 WebView 登录',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '应用内打开 ${site.name} 登录页，登录后自动抓取 Cookie',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('打开登录页'),
                  onPressed: site.baseUrl != null ? _openWebView : null,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 清除 Cookie
        if (hasCookie)
          OutlinedButton.icon(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            label:
                const Text('清除 Cookie', style: TextStyle(color: Colors.red)),
            onPressed: () => _clearCookie(provider),
          ),
      ],
    );
  }

  Widget _buildWebView() {
    if (site.baseUrl == null) {
      return const Center(child: Text('站点没有配置 URL'));
    }

    _webViewCtrl ??= WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            try {
              final provider = context.read<SiteProvider>();
              final result = await _webViewCtrl!
                  .runJavaScriptReturningResult('document.cookie');
              final cookie = result.toString();
              if (cookie.isNotEmpty && cookie != 'null') {
                await provider.saveCookie(site.id, cookie);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Cookie 已抓取'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            } catch (_) {}
          },
        ),
      )
      ..loadRequest(Uri.parse(site.baseUrl!));

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Theme.of(context).colorScheme.surface,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _webViewVisible = false),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => setState(() => _webViewVisible = false),
                child: const Text('完成登录'),
              ),
            ],
          ),
        ),
        Expanded(child: WebViewWidget(controller: _webViewCtrl!)),
      ],
    );
  }

  Future<void> _saveManualCookie(SiteProvider provider) async {
    final cookie = _cookieCtrl.text.trim();
    if (cookie.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入 Cookie 字符串')),
      );
      return;
    }
    await provider.saveCookie(site.id, cookie);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Cookie 已保存'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _clearCookie(SiteProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除 Cookie'),
        content: const Text('确定要清除该站点的 Cookie 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.deleteCookie(site.id);
      _cookieCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cookie 已清除')),
        );
      }
    }
  }

  void _openWebView() {
    setState(() => _webViewVisible = true);
  }
}
