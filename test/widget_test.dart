import 'package:flutter_test/flutter_test.dart';
import 'package:bit_manager/main.dart';

void main() {
  testWidgets('App should build without error', (WidgetTester tester) async {
    await tester.pumpWidget(const BitManagerApp());
    // Verify the app shell renders
    expect(find.text('Bit Manager'), findsWidgets);
  });
}
