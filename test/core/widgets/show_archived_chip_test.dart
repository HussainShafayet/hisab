import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/widgets/show_archived_chip.dart';

Future<void> pump(
  WidgetTester tester, {
  required bool value,
  ValueChanged<bool>? onChanged,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ShowArchivedChip(value: value, onChanged: onChanged ?? (_) {}),
      ),
    ),
  );
}

void main() {
  testWidgets('says what it does, in words', (tester) async {
    await pump(tester, value: false);

    expect(find.text('Show archived'), findsOneWidget);
  });

  testWidgets('shows whether it is on', (tester) async {
    await pump(tester, value: true);

    expect(
      tester
          .widget<FilterChip>(find.byKey(const ValueKey('show-archived')))
          .selected,
      isTrue,
    );
  });

  testWidgets('reports the new value when tapped', (tester) async {
    bool? reported;
    await pump(tester, value: false, onChanged: (value) => reported = value);

    await tester.tap(find.byKey(const ValueKey('show-archived')));

    expect(reported, isTrue);
  });
}
