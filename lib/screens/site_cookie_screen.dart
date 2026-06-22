import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_cookie_manager/webview_cookie_manager.dart';
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
  final _cookieManager = WebviewCookieManager();
  bool _webViewVisible = false;
  WebViewController? _webViewCtrl;
  String? _currentWebUrl;

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
            label: const Text('清除 Cookie', style: TextStyle(color: Colors.red)),
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
          onPageFinished: (url) {
            // 仅记录当前页 URL，不在这里抓 cookie:
            // 1) document.cookie 拿不到 HttpOnly（NexusPHP 鉴权 cookie 全是 HttpOnly）
            // 2) 登录前的页面自动保存会把空/无效 cookie 覆盖掉真 cookie
            // 改为用户点「完成登录」时调用 WebviewCookieManager.getCookies 拉取
            _currentWebUrl = url;
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
                onPressed: _captureCookieAndClose,
                child: const Text('完成登录'),
              ),
            ],
          ),
        ),
        Expanded(child: WebViewWidget(controller: _webViewCtrl!)),
      ],
    );
  }

  /// 用户点「完成登录」时触发：通过原生 CookieManager 抓 cookie（含 HttpOnly）
  Future<void> _captureCookieAndClose() async {
    final messenger = ScaffoldMessenger.of(context);
    final provider = context.read<SiteProvider>();

    final url = _currentWebUrl ?? site.baseUrl!;
    String? cookieString;
    int cookieCount = 0;
    String? warnHint;

    // 优先：原生 CookieManager（能读 HttpOnly，NexusPHP 鉴权依赖这个）
    try {
      final cookies = await _cookieManager.getCookies(url);
      final now = DateTime.now();
      final parts = <String>[];
      for (final c in cookies) {
        if (c.expires != null && c.expires!.isBefore(now)) continue;
        if (c.name.isEmpty) continue;
        parts.add('${c.name}=${c.value}');
      }
      if (parts.isNotEmpty) {
        cookieString = parts.join('; ');
        cookieCount = parts.length;
      }
    } on Exception catch (e) {
      // 常见：MissingPluginException — 加完插件后没重新构建就会报
      warnHint = e.toString().contains('MissingPluginException')
          ? '原生插件未加载（加完依赖后需要完整重启 app，而非热重载）'
          : e.toString();
    }

    // 降级：document.cookie（只能拿到非 HttpOnly cookie）
    // 防御：必须含至少一个 NexusPHP 鉴权关键词才接受 — 否则只 lang=en / theme=dark
    // 之类的非鉴权 cookie 也会被误存为「已登录」状态，将来 fetchUserInfo 直接登出循环。
    if (cookieString == null && _webViewCtrl != null) {
      try {
        final result = await _webViewCtrl!.runJavaScriptReturningResult(
          'document.cookie',
        );
        final raw = result.toString();
        final cleaned = raw.startsWith('"') && raw.endsWith('"')
            ? raw.substring(1, raw.length - 1)
            : raw;
        final hasAuthToken = RegExp(
          r'\b(c_secure_(uid|pass|login|ssl)|uid|user_id|PHPSESSID|pass)=',
          caseSensitive: false,
        ).hasMatch(cleaned);
        if (cleaned.length > 10 && cleaned.contains('=') && hasAuthToken) {
          cookieString = cleaned;
          cookieCount = cleaned.split(';').length;
          warnHint =
              '${warnHint ?? ''}；当前用 document.cookie 降级抓取，'
              'HttpOnly cookie 拿不到，NexusPHP 鉴权很可能失败';
        } else if (cleaned.length > 10 && cleaned.contains('=')) {
          // 抓到了 cookie 但没有鉴权 token — 几乎一定是降级失效
          warnHint =
              '${warnHint ?? ''}；document.cookie 降级只拿到非鉴权 '
              'cookie（lang/theme 等），未发现 c_secure_/uid/PHPSESSID — '
              '请确认 WebView 里已登录成功';
        }
      } catch (_) {
        // ignore
      }
    }

    if (cookieString == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            warnHint != null ? '抓取 Cookie 失败：$warnHint' : '未抓到 Cookie，请确认已登录',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    await provider.saveCookie(site.id, cookieString);

    // 把抓到的 cookie 回填到文本框，方便用户查看 / 微调后再次保存。
    // （已自动保存一次；用户编辑后点「保存 Cookie」会覆盖为新内容。）
    _cookieCtrl.text = cookieString;

    // 检查是否含有 NexusPHP 鉴权字段
    final hasUid = RegExp(
      r'\b(c_secure_uid|uid|user_id)=',
    ).hasMatch(cookieString);
    if (!mounted) return;
    setState(() => _webViewVisible = false);
    final bg = !hasUid
        ? Colors.orange
        : warnHint != null
        ? Colors.amber
        : Colors.green;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          !hasUid
              ? '已抓 $cookieCount 项 Cookie，但未发现 uid — 可能未登录成功'
              : warnHint != null
              ? '已抓 $cookieCount 项（降级模式，可能不完整）'
              : 'Cookie 已抓取（$cookieCount 项）',
        ),
        backgroundColor: bg,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _saveManualCookie(SiteProvider provider) async {
    final cookie = _cookieCtrl.text.trim();
    if (cookie.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入 Cookie 字符串')));
      return;
    }
    await provider.saveCookie(site.id, cookie);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cookie 已保存'),
          backgroundColor: Colors.green,
        ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cookie 已清除')));
      }
    }
  }

  void _openWebView() {
    setState(() => _webViewVisible = true);
  }
}
