import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';
import 'reports_screen_test.dart' show openReports, seedReports;

// Today is Sunday 11 October 2026. The seeded data has September (income
// 30,000, Food 1,000) and October (income 50,000, spending 10,000).

Future<void> showYear(WidgetTester tester) async {
  await tester.tap(find.text('Year'));
  await tester.pumpAndSettle();
}

String yearLabel(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('year-label'))).data!;

void main() {
  group('the year view', () {
    testWithDatabase('opens on this year, with a row for each month so far', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedReports(db);
      await pumpAppWithDatabase(tester, db);
      await openReports(tester);

      await showYear(tester);

      expect(yearLabel(tester), '2026');
      expect(find.byKey(const ValueKey('month-by-month')), findsOneWidget);
      for (var m = 1; m <= 10; m++) {
        expect(find.byKey(ValueKey('month-row-$m')), findsOneWidget);
      }
      // November and December have not come.
      expect(find.byKey(const ValueKey('month-row-11')), findsNothing);
      expect(find.byKey(const ValueKey('month-row-12')), findsNothing);
    });

    testWithDatabase('says what each month left', (tester, db) async {
      useTallScreen(tester);
      await seedReports(db);
      await pumpAppWithDatabase(tester, db);
      await openReports(tester);

      await showYear(tester);

      Finder inRow(int month, String text) => find.descendant(
        of: find.byKey(ValueKey('month-row-$month')),
        matching: find.text(text),
      );
      // September: 30,000 in, 1,000 out. October: 50,000 in, 10,000 out.
      expect(inRow(9, '+৳29,000.00'), findsOneWidget);
      expect(inRow(10, '+৳40,000.00'), findsOneWidget);
      // A month with nothing says so with a dash.
      expect(inRow(3, '–'), findsOneWidget);
    });

    testWithDatabase('the year adds up, and is compared with the year before', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedReports(db);
      await pumpAppWithDatabase(tester, db);
      await openReports(tester);

      await showYear(tester);

      expect(find.text('Compared with 2025'), findsOneWidget);
      // Income 80,000 and expense 11,000 in all.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('report-summary')),
          matching: find.text('৳80,000.00'),
        ),
        findsWidgets,
      );
      expect(
        find.text('Average per month: income ৳40,000.00, expense ৳5,500.00'),
        findsOneWidget,
      );
      expect(find.text('Most spent: October, ৳10,000.00'), findsOneWidget);
      expect(find.text('Most kept: October, ৳40,000.00'), findsOneWidget);
      expect(
        find.text('Averages are over the 2 months with entries.'),
        findsOneWidget,
      );
    });

    testWithDatabase('has the chart of the twelve months, not of six', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await seedReports(db);
      await pumpAppWithDatabase(tester, db);
      await openReports(tester);

      await showYear(tester);

      // One chart, and it is the year's.
      expect(
        find.byKey(const ValueKey('income-expense-chart')),
        findsOneWidget,
      );
    });

    testWithDatabase(
      'the arrows go to the year before, and not past this one',
      (tester, db) async {
        useTallScreen(tester);
        await seedReports(db);
        await pumpAppWithDatabase(tester, db);
        await openReports(tester);
        await showYear(tester);
        bool nextEnabled() =>
            tester
                .widget<IconButton>(find.byKey(const ValueKey('year-next')))
                .onPressed !=
            null;
        expect(nextEnabled(), isFalse);

        await tester.tap(find.byKey(const ValueKey('year-previous')));
        await tester.pumpAndSettle();

        expect(yearLabel(tester), '2025');
        expect(find.text('Compared with 2024'), findsOneWidget);
        // A past year lists all twelve months.
        expect(find.byKey(const ValueKey('month-row-12')), findsOneWidget);
        expect(nextEnabled(), isTrue);
        expect(find.textContaining('Average per month'), findsNothing);

        await tester.tap(find.byKey(const ValueKey('year-next')));
        await tester.pumpAndSettle();
        expect(yearLabel(tester), '2026');
      },
    );

    testWithDatabase('a tap on a month opens that month', (tester, db) async {
      useTallScreen(tester);
      await seedReports(db);
      await pumpAppWithDatabase(tester, db);
      await openReports(tester);
      await showYear(tester);

      await tester.ensureVisible(find.byKey(const ValueKey('month-row-9')));
      await tester.tap(find.byKey(const ValueKey('month-row-9')));
      await tester.pumpAndSettle();

      expect(find.text('September 2026'), findsOneWidget);
      expect(find.byKey(const ValueKey('year-label')), findsNothing);
      expect(find.text('Compared with August 2026'), findsOneWidget);
    });

    testWithDatabase('Month brings back the month view', (tester, db) async {
      useTallScreen(tester);
      await seedReports(db);
      await pumpAppWithDatabase(tester, db);
      await openReports(tester);
      await showYear(tester);

      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();

      expect(find.text('October 2026'), findsOneWidget);
      expect(find.byKey(const ValueKey('month-by-month')), findsNothing);
    });

    testWithDatabase('an older year with data is read in full', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedReports(db);
      await addTransaction(
        db,
        type: TransactionType.expense,
        amount: 400000,
        accountId: b.basics.cash,
        categoryId: b.basics.food,
        date: DateTime(2025, 3, 5, 12),
      );
      await pumpAppWithDatabase(tester, db);
      await openReports(tester);
      await showYear(tester);

      await tester.tap(find.byKey(const ValueKey('year-previous')));
      await tester.pumpAndSettle();

      expect(find.text('Most spent: March, ৳4,000.00'), findsOneWidget);
    });

    testWithDatabase(
      'opening the custom range keeps the year view until a range is chosen',
      (tester, db) async {
        useTallScreen(tester);
        await seedReports(db);
        await pumpAppWithDatabase(tester, db);
        await openReports(tester);
        await showYear(tester);

        await tester.tap(find.byTooltip('Custom date range'));
        await tester.pumpAndSettle();

        // The date range dialog opens; leaving it keeps the year view.
        expect(find.byKey(const ValueKey('year-label')), findsOneWidget);
      },
    );
  });
}
