import 'package:flutter_test/flutter_test.dart';
import 'package:tubegrow/main.dart';

void main() {
  testWidgets('App launches correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const TubeToolApp());
    await tester.pump(const Duration(milliseconds: 500));
    // Verify splash screen shows TubeTool
    expect(find.text('TubeTool'), findsOneWidget);
    // Advance timers so splash finishes without dangling timer assertion
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
  });
}
