import 'package:bit_manager/models/client_config.dart';
import 'package:bit_manager/providers/client_provider.dart';
import 'package:bit_manager/providers/torrent_provider.dart';
import 'package:bit_manager/screens/torrent_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('filter sheet fits on short screens without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});

    final clientProvider = ClientProvider();
    await clientProvider.addClient(
      ClientConfig(
        id: 'client-1',
        name: 'Client 1',
        type: ClientType.qBittorrent,
        host: '127.0.0.1',
        port: 8080,
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ClientProvider>.value(value: clientProvider),
          ChangeNotifierProvider(create: (_) => TorrentProvider()),
        ],
        child: const MaterialApp(home: TorrentListScreen()),
      ),
    );

    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
