import 'package:flutter_test/flutter_test.dart';
import 'package:bit_manager/main.dart';

void main() {
  testWidgets('App should build without error', (WidgetTester tester) async {
    await tester.pumpWidget(const BitManagerApp());
    // 验证 4 个 Tab 存在
    expect(find.text('站点'), findsWidgets);
    expect(find.text('下载器'), findsWidgets);
    expect(find.text('种子'), findsWidgets);
    expect(find.text('设置'), findsWidgets);
  });
}
