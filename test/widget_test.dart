// This is a basic Flutter widget test.
import 'package:flutter_test/flutter_test.dart';
import 'package:ahmed_debts/main.dart';

void main() {
  testWidgets('App should build without errors', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const GhazaliDebtApp());
    
    // Verify app title is displayed
    expect(find.text('ديون الغزالي'), findsAny);
  });
}
