import 'package:flutter_test/flutter_test.dart';
import 'package:rib_scanner/main.dart';

void main() {
  testWidgets('Splash screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RibScannerApp());
    expect(find.text('Rib 9 Scanner'), findsOneWidget);
  });
}
