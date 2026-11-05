import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/investments/data/investments_repository.dart';
import 'package:hishab/features/investments/domain/investment.dart';

import '../../../helpers/pump_app.dart';

// Today is Sunday 11 October 2026.
Future<int> make(
  InvestmentsRepository repo,
  String name, {
  DateTime? started,
  int putIn = 1000000,
  int profit = 0,
}) async {
  final id = await repo.createInvestment(
    name: name,
    startedOn: started ?? DateTime(2026, 4, 11),
  );
  if (putIn > 0) {
    await repo.addEntry(
      id,
      kind: InvestmentEntryKind.putIn,
      amount: putIn,
      date: started ?? DateTime(2026, 4, 11),
    );
  }
  if (profit > 0) {
    await repo.addEntry(
      id,
      kind: InvestmentEntryKind.profit,
      amount: profit,
      date: DateTime(2026, 10, 3),
    );
  }
  return id;
}

void main() {
  group('an investment page tells how it is going', () {
    testWithDatabase('how long, how much is back, and the pace', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final repo = InvestmentsRepository(db);
      final id = await make(repo, 'Shop', profit: 183000);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Investments');
      await tester.tap(find.byKey(ValueKey('investment-$id')));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('facts-held'))).data,
        'Held for 6 months',
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('facts-recovered'))).data,
        '18% of the money put in is back.',
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('facts-per-month'))).data,
        'Profit is about ৳300.00 a month.',
      );
      expect(find.byKey(const ValueKey('facts-payback')), findsOneWidget);
      expect(find.byKey(const ValueKey('profit-bar-2026-10')), findsOneWidget);
    });

    testWithDatabase('a young investment gives no rate yet', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final repo = InvestmentsRepository(db);
      final id = await make(repo, 'New', started: DateTime(2026, 10, 5));
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Investments');
      await tester.tap(find.byKey(ValueKey('investment-$id')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('facts-annual')), findsNothing);
      expect(find.byKey(const ValueKey('facts-per-month')), findsNothing);
    });
  });

  group('the list of investments', () {
    testWithDatabase('can be narrowed to the open or the closed ones', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final repo = InvestmentsRepository(db);
      final open = await make(repo, 'Open one');
      final closed = await make(repo, 'Old one');
      await repo.setClosed(closed, closed: true);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Investments');

      expect(find.text('All · 2'), findsOneWidget);
      expect(find.text('Open · 1'), findsOneWidget);
      expect(find.text('Closed · 1'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('inv-closed')));
      await tester.pumpAndSettle();
      expect(find.byKey(ValueKey('investment-$closed')), findsOneWidget);
      expect(find.byKey(ValueKey('investment-$open')), findsNothing);
    });

    testWithDatabase('can put the best return first and name the best', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final repo = InvestmentsRepository(db);
      await make(repo, 'Slow', profit: 10000);
      await make(repo, 'Fast', profit: 500000);
      await pumpAppWithDatabase(tester, db);
      await openFromMore(tester, 'Investments');

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('investment-best'))).data,
        'Best so far: Fast, 50%',
      );

      await tester.tap(find.byKey(const ValueKey('investment-sort')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Best return first'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Fast')).dy,
        lessThan(tester.getTopLeft(find.text('Slow')).dy),
      );
    });
  });
}
