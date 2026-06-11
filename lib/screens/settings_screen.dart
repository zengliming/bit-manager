import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 关于
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Bit Manager'),
              subtitle: Text('版本 1.0.0'),
            ),
          ),
        ],
      ),
    );
  }
}
