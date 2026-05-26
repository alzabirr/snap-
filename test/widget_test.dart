import 'package:flutter_test/flutter_test.dart';
import 'package:snap/main.dart';

void main() {
  testWidgets('SnapApp Onboarding build test', (WidgetTester tester) async {
    // Build SnapApp starting in Onboarding mode
    await tester.pumpWidget(const SnapApp(isFirstLaunch: true));

    // Verify Onboarding elements are present
    expect(find.text('Snap your thoughts'), findsOneWidget);
  });
}
