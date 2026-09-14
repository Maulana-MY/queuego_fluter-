import 'package:flutter_test/flutter_test.dart';
import 'package:queue_go/main.dart';

void main() {
  testWidgets('QueueGo smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const QueueGoApp());

    // Verify that QueueGo title exists on splash screen.
    expect(find.text('QueueGo'), findsWidgets);
  });
}
