import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/fun/presentation/celebrate.dart';
import 'package:hishab/features/settings/domain/app_preferences.dart';
import 'package:hishab/features/settings/presentation/providers/settings_providers.dart';

Finder confetti() => find.byWidgetPredicate(
  (w) =>
      w is CustomPaint && w.painter.runtimeType.toString().contains('Confetti'),
);

Future<void> pumpButton(WidgetTester tester, {required bool fun}) =>
    tester.pumpWidget(
      ProviderScope(
        overrides: [
          initialPreferencesProvider.overrideWithValue(
            AppPreferences(funMode: fun),
          ),
        ],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () => celebrate(context, ref),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('throws confetti when Fun mode is on', (tester) async {
    await pumpButton(tester, fun: true);
    await tester.tap(find.text('go'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(confetti(), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('stays quiet when Fun mode is off', (tester) async {
    await pumpButton(tester, fun: false);
    await tester.tap(find.text('go'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(confetti(), findsNothing);
  });
}
