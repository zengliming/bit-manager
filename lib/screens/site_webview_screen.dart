import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_cookie_manager/webview_cookie_manager.dart';

import '../models/site_config.dart';
import '../utils/storage.dart';

/// 通用站内 WebView 屏
///
/// 启动时把 SecureStorage 里的 `cookie_{site.id}` 拆成单条 cookie 注入到原生
/// WebView 的 cookie jar，然后 `loadRequest(baseUrl + path)`。复用
/// `site_cookie_screen.dart` 已验证过的 cookie 注入路径。
class SiteWebViewScreen extends StatefulWidget {
  final SiteConfig site;

  /// 站内相对路径，如 '/messages.php' 或 '/inbox.php'
  final String path;

  const SiteWebViewScreen({super.key, required this.site, required this.path});

  @override
  State<SiteWebViewScreen> createState() => _SiteWebViewScreenState();
}

class _SiteWebViewScreenState extends State<SiteWebViewScreen> {
  final WebviewCookieManager _cookieManager = WebviewCookieManager();
  WebViewController? _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _controller = null;
    super.dispose();
  }

  String? get _baseUrl => widget.site.baseUrl;
  String get _cookieStorageKey => 'cookie_${widget.site.id}';

  Future<void> _bootstrap() async {
    final baseUrl = _baseUrl;
    if (baseUrl == null || baseUrl.isEmpty) {
      setState(() {
        _loading = false;
        _error = '该站点未配置 URL';
      });
      return;
    }
    try {
      final storage = await LocalStorage.getInstance();
      final cookie = await storage.getString(_cookieStorageKey);
      if (cookie == null || cookie.isEmpty) {
        setState(() {
          _loading = false;
          _error = '该站点未配置 Cookie';
        });
        return;
      }
      final uri = Uri.parse(_joinUrl(baseUrl, widget.path));
      await _injectCookies(uri, cookie);
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (mounted) setState(() => _loading = false);
            },
            onWebResourceError: (e) {
              if (mounted) {
                setState(() {
                  _loading = false;
                  _error = '加载失败：${e.description}';
                });
              }
            },
          ),
        )
        ..loadRequest(uri);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '启动失败：$e';
        });
      }
    }
  }

  Future<void> _injectCookies(Uri uri, String cookie) async {
    final cookies = <Cookie>[];
    for (final p in cookie.split(';')) {
      final trimmed = p.trim();
      if (trimmed.isEmpty) continue;
      final eq = trimmed.indexOf('=');
      if (eq <= 0) continue;
      final name = trimmed.substring(0, eq).trim();
      final value = trimmed.substring(eq + 1).trim();
      if (name.isEmpty) continue;
      cookies.add(
        Cookie(name, value)
          ..domain = uri.host
          ..path = '/',
      );
    }
    if (cookies.isEmpty) return;
    await _cookieManager.setCookies(cookies, origin: uri.toString());
  }

  String _joinUrl(String baseUrl, String path) {
    final base = Uri.parse(baseUrl);
    return base.resolveUri(Uri.parse(path)).toString();
  }

  Future<void> _retry() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    _controller = null;
    await _bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    final site = widget.site;
    final title = '${site.name} · ${_pageTitle(widget.path)}';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: '关闭',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
        bottom: _loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: _error != null
          ? _buildError(_error!)
          : (_controller == null
                ? const Center(child: CircularProgressIndicator())
                : WebViewWidget(controller: _controller!)),
    );
  }

  Widget _buildError(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(msg, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
              onPressed: _retry,
            ),
          ],
        ),
      ),
    );
  }

  String _pageTitle(String path) {
    if (path.contains('inbox')) return '消息';
    if (path.contains('messages')) return '消息';
    return '站内';
  }
}
