import 'package:flutter_test/flutter_test.dart';
import 'package:privault/main.dart';

void main() {
  testWidgets('App load smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // Note: We don't use 'const' here because PriVaultApp doesn't have a const constructor
    await tester.pumpWidget(const PriVaultApp());

    // Basic check if the login screen is there
    expect(find.text('PriVault Login'), findsOneWidget);
  });
}
