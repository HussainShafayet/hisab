import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// With the time picker open, switches it to typing and enters [hour] and
/// [minute] (12-hour clock, AM/PM left as it is), then presses OK.
Future<void> typeTimeInPicker(
  WidgetTester tester, {
  required String hour,
  required String minute,
}) async {
  await tester.tap(find.byIcon(Icons.keyboard_outlined));
  await tester.pumpAndSettle();
  final fields = find.descendant(
    of: find.byType(Dialog),
    matching: find.byType(TextField),
  );
  await tester.enterText(fields.at(0), hour);
  await tester.enterText(fields.at(1), minute);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}
