// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:my_records/main.dart';

void main() {
  testWidgets('My Records app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyRecordsApp());

    // Verify that our app shows the expected title.
    expect(find.text('My Records'), findsOneWidget);
    expect(find.text('Welcome back!'), findsOneWidget);

    // Verify that category cards are present
    expect(find.text('Certificates'), findsOneWidget);
    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('Education'), findsOneWidget);
    expect(find.text('Personal Info'), findsOneWidget);
  });
}
