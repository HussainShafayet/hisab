import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/challenges/domain/challenge.dart';
import 'package:hishab/features/challenges/presentation/providers/challenges_providers.dart';

import '../../../helpers/pump_app.dart';

void main() {
  testWithDatabase(
    'a screen that could not load offers Retry, and Retry loads again',
    (tester, db) async {
      useTallScreen(tester);
      var loads = 0;
      await pumpAppWithDatabase(
        tester,
        db,
        overrides: [
          challengesProvider.overrideWith((ref) {
            loads++;
            return Stream<List<ChallengeItem>>.error(StateError('no database'));
          }),
        ],
      );
      await openFromMore(tester, 'Challenges');

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
      final before = loads;

      await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
      await tester.pumpAndSettle();

      // The screen asked for its data again.
      expect(loads, greaterThan(before));
      expect(find.text('Something went wrong'), findsOneWidget);
    },
  );
}
