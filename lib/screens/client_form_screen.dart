import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/client_config.dart';
import '../providers/client_provider.dart';

class ClientFormScreen extends StatefulWidget {
  final ClientConfig? client;
  const ClientFormScreen({super.key, this.client});

  @override
  State<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends State<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _hostCtrl;
  late final TextEditingController _portCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _timeoutCtrl;
  late final TextEditingController _savePathCtrl;
  late ClientType _type;
  late bool _useSsl;

  bool get isEditing => widget.client != null;

  @override
  void initState() {
    super.initState();
    final c = widget.client;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _hostCtrl = TextEditingController(text: c?.host ?? '');
    _portCtrl = TextEditingController(text: c?.port.toString() ?? (c?.type == ClientType.qBittorrent ? '8080' : '9091'));
    _usernameCtrl = TextEditingController(text: c?.username ?? '');
    _passwordCtrl = TextEditingController(text: c?.password ?? '');
    _timeoutCtrl = TextEditingController(text: (c?.timeoutSeconds ?? 10).toString());
    _savePathCtrl = TextEditingController(text: c?.defaultSavePath ?? '');
    _type = c?.type ?? ClientType.qBittorrent;
    _useSsl = c?.useSsl ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _timeoutCtrl.dispose();
    _savePathCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? '编辑客户端' : '添加客户端')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextFormField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: '名称', hintText: '例如: NAS-4T'),
                validator: (v) => (v == null || v.trim().isEmpty) ? '请输入名称' : null,
              ),
              const SizedBox(height: 16),
              SegmentedButton<ClientType>(
                segments: const [
                  ButtonSegment(value: ClientType.qBittorrent, label: Text('qBittorrent')),
                  ButtonSegment(value: ClientType.transmission, label: Text('Transmission')),
                ],
                selected: {_type},
                onSelectionChanged: (v) {
                  setState(() {
                    _type = v.first;
                    if (!isEditing) {
                      _portCtrl.text = _type == ClientType.qBittorrent ? '8080' : '9091';
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _hostCtrl,
                decoration: const InputDecoration(labelText: '地址', hintText: 'IP 或域名'),
                validator: (v) => (v == null || v.trim().isEmpty) ? '请输入地址' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _portCtrl,
                decoration: const InputDecoration(labelText: '端口'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return '请输入端口';
                  final port = int.tryParse(v);
                  if (port == null || port < 1 || port > 65535) return '无效端口';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('使用 HTTPS'),
                value: _useSsl,
                onChanged: (v) => setState(() => _useSsl = v),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameCtrl,
                decoration: const InputDecoration(labelText: '用户名（可选）'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordCtrl,
                decoration: const InputDecoration(labelText: '密码'),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _timeoutCtrl,
                decoration: const InputDecoration(
                  labelText: '超时时间（秒）',
                  hintText: '10',
                  helperText: '请求超时时间，默认 10 秒',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _savePathCtrl,
                decoration: const InputDecoration(
                  labelText: '默认保存路径（可选）',
                  hintText: '/downloads',
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _submit,
                child: Text(isEditing ? '保存' : '添加'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ClientProvider>();
    final config = ClientConfig(
      id: widget.client?.id ?? const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      type: _type,
      host: _hostCtrl.text.trim(),
      port: int.parse(_portCtrl.text.trim()),
      username: _usernameCtrl.text.trim().isEmpty ? null : _usernameCtrl.text.trim(),
      password: _passwordCtrl.text.trim().isEmpty ? null : _passwordCtrl.text.trim(),
      useSsl: _useSsl,
      timeoutSeconds: int.tryParse(_timeoutCtrl.text.trim()) ?? 10,
      defaultSavePath: _savePathCtrl.text.trim().isEmpty ? null : _savePathCtrl.text.trim(),
    );

    if (isEditing) {
      await provider.updateClient(widget.client!.id, config);
    } else {
      await provider.addClient(config);
    }

    if (mounted) Navigator.pop(context);
  }
}
