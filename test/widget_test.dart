// Smoke test for a plain widget. The full app boots Supabase in main(),
// which needs the network/.env, so widget tests here use isolated widgets.
// Business logic is covered by expense_parser_test.dart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MaterialApp renders a child', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('ok'))),
    );
    expect(find.text('ok'), findsOneWidget);
  });
}
