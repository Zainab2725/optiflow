// This is a basic Flutter widget test for OptiFlowApp.

import 'package:flutter_test/flutter_test.dart';
import 'package:optiflow_app/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const OptiFlowApp());

    // Verify that the splash screen or initial widgets are rendered.
    expect(find.byType(OptiFlowApp), findsOneWidget);
  });
}

