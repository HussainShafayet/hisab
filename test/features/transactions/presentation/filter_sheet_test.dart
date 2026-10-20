import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:hishab/features/categories/presentation/providers/categories_providers.dart';
import 'package:hishab/features/tags/domain/tag.dart';
import 'package:hishab/features/tags/presentation/providers/tags_providers.dart';
import 'package:hishab/features/transactions/data/saved_filters_repository.dart';
import 'package:hishab/features/transactions/domain/feeling.dart';
import 'package:hishab/features/transactions/domain/transaction_filter.dart';
import 'package:hishab/features/transactions/presentation/widgets/transaction_filter_sheet.dart';

import '../../../helpers/pump_app.dart';

Widget sheet(List<Override> overrides) => ProviderScope(
  // No automatic retry, so a failing provider does not leave timers behind.
  retry: (_, _) => null,
  overrides: overrides,
  child: const MaterialApp(
    home: Scaffold(body: TransactionFilterSheet(initial: TransactionFilter())),
  ),
);

void main() {
  testWidgets(
    'shows a loading indicator until accounts and categories arrive',
    (tester) async {
      await tester.pumpWidget(
        sheet([
          accountsProvider(true).overrideWith((ref) => const Stream.empty()),
          categoriesProvider(true).overrideWith((ref) => const Stream.empty()),
        ]),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Apply'), findsNothing);
    },
  );

  testWidgets('shows the error, not an endless spinner, when loading fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      sheet([
        accountsProvider(true).overrideWith(
          (ref) => Stream.error(const ValidationException('Database is down')),
        ),
        categoriesProvider(true).overrideWith((ref) => const Stream.empty()),
      ]),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Database is down'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  group('the amount, trip and feeling options', () {
    TransactionFilter? result;

    /// A page with a button that opens the sheet, so Apply has somewhere to
    /// pop to. [result] is what the sheet gave back.
    Widget opener({TransactionFilter initial = const TransactionFilter()}) {
      result = null;
      return ProviderScope(
        retry: (_, _) => null,
        overrides: [
          accountsProvider(true).overrideWith((ref) => Stream.value(const [])),
          categoriesProvider(true)
              .overrideWith((ref) => Stream.value(const [])),
          tagsProvider.overrideWith(
            (ref) => Stream.value(const [Tag(id: 3, name: 'Cox trip')]),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showModalBottomSheet<TransactionFilter>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => TransactionFilterSheet(initial: initial),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
    }

    Future<void> open(WidgetTester tester, Widget app) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Future<void> type(WidgetTester tester, String key, String text) async {
      await tester.enterText(find.byKey(ValueKey(key)), text);
      await tester.pump();
    }

    Future<void> apply(WidgetTester tester) async {
      await tester.ensureVisible(find.byKey(const ValueKey('filter-apply')));
      await tester.tap(find.byKey(const ValueKey('filter-apply')));
      await tester.pumpAndSettle();
    }

    testWidgets('gives back an amount range in poisha', (tester) async {
      await open(tester, opener());

      await type(tester, 'filter-min-amount', '500');
      await type(tester, 'filter-max-amount', '1,500.50');
      await apply(tester);

      expect(result!.minAmount, 50000);
      expect(result!.maxAmount, 150050);
    });

    testWidgets('leaves an empty end open', (tester) async {
      await open(tester, opener());

      await type(tester, 'filter-min-amount', '200');
      await apply(tester);

      expect(result!.minAmount, 20000);
      expect(result!.maxAmount, isNull);
    });

    testWidgets('does not close on text that is not an amount', (tester) async {
      await open(tester, opener());

      await type(tester, 'filter-max-amount', 'lots');
      await apply(tester);

      expect(find.byKey(const ValueKey('filter-amount-error')), findsOneWidget);
      expect(find.text('Enter the amount as a number.'), findsOneWidget);
      expect(find.byKey(const ValueKey('filter-apply')), findsOneWidget);
      expect(result, isNull);
    });

    testWidgets('does not close when the smallest is above the largest', (
      tester,
    ) async {
      await open(tester, opener());

      await type(tester, 'filter-min-amount', '900');
      await type(tester, 'filter-max-amount', '100');
      await apply(tester);

      expect(
        find.text('The smallest amount is above the largest.'),
        findsOneWidget,
      );
      expect(result, isNull);

      // Typing again clears the message.
      await type(tester, 'filter-min-amount', '50');
      expect(find.byKey(const ValueKey('filter-amount-error')), findsNothing);
    });

    testWidgets('chooses a trip and a feeling', (tester) async {
      await open(tester, opener());

      await tester.ensureVisible(find.byKey(const ValueKey('filter-tag')));
      await tester.tap(find.byKey(const ValueKey('filter-tag')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cox trip').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('filter-feeling-regret')));
      await tester.pump();
      await apply(tester);

      expect(result!.tagId, 3);
      expect(result!.feeling, Feeling.regret);
    });

    testWidgets('shows what was already set', (tester) async {
      await open(
        tester,
        opener(
          initial: const TransactionFilter(
            minAmount: 20000,
            tagId: 3,
            feeling: Feeling.want,
          ),
        ),
      );

      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('filter-min-amount')))
            .controller!
            .text,
        '200',
      );
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('filter-feeling-want')),
            )
            .selected,
        isTrue,
      );
      await apply(tester);
      expect(result!.minAmount, 20000);
      expect(result!.tagId, 3);
      expect(result!.feeling, Feeling.want);
    });

    testWidgets('Clear all drops the new options too', (tester) async {
      await open(
        tester,
        opener(
          initial: const TransactionFilter(
            query: 'tea',
            maxAmount: 9000,
            feeling: Feeling.need,
          ),
        ),
      );

      await tester.ensureVisible(find.text('Clear all'));
      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();

      expect(result!.query, 'tea');
      expect(result!.maxAmount, isNull);
      expect(result!.feeling, isNull);
    });
  });

  group('saved filters', () {
    TransactionFilter? result;
    Widget opener(
      AppDatabase db, {
      TransactionFilter initial = const TransactionFilter(),
    }) {
      result = null;
      return ProviderScope(
        retry: (_, _) => null,
        overrides: [
          accountsProvider(true).overrideWith((ref) => Stream.value(const [])),
          categoriesProvider(true)
              .overrideWith((ref) => Stream.value(const [])),
          tagsProvider.overrideWith((ref) => Stream.value(const [])),
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showModalBottomSheet<TransactionFilter>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => TransactionFilterSheet(initial: initial),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
    }

    Future<void> open(WidgetTester tester, Widget app) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWithDatabase('are not offered while there are none', (
      tester,
      db,
    ) async {
      await open(tester, opener(db));

      expect(find.text('Saved filters'), findsNothing);
      expect(find.byKey(const ValueKey('save-filter')), findsOneWidget);
    });

    testWithDatabase('need at least one option to be saved', (
      tester,
      db,
    ) async {
      final saved = SavedFiltersRepository(db);
      await open(tester, opener(db));

      await tester.ensureVisible(find.byKey(const ValueKey('save-filter')));
      await tester.tap(find.byKey(const ValueKey('save-filter')));
      await tester.pumpAndSettle();

      expect(find.text('Pick at least one option to save.'), findsOneWidget);
      expect(find.byKey(const ValueKey('saved-filter-name')), findsNothing);
      expect(await saved.getAll(), isEmpty);
    });

    testWithDatabase('the options are saved under the name that was typed', (
      tester,
      db,
    ) async {
      final saved = SavedFiltersRepository(db);
      await open(tester, opener(db));
      await tester.enterText(
        find.byKey(const ValueKey('filter-min-amount')),
        '500',
      );
      await tester.tap(find.byKey(const ValueKey('filter-feeling-regret')));
      await tester.pump();

      await tester.ensureVisible(find.byKey(const ValueKey('save-filter')));
      await tester.tap(find.byKey(const ValueKey('save-filter')));
      await tester.pumpAndSettle();
      // Nothing to save without a name.
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('saved-filter-save')),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const ValueKey('saved-filter-name')),
        'Regret over 500',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('saved-filter-save')));
      await tester.pumpAndSettle();

      final all = await saved.getAll();
      expect(all.single.name, 'Regret over 500');
      expect(all.single.filter.minAmount, 50000);
      expect(all.single.filter.feeling, Feeling.regret);
      // And it shows as a chip.
      expect(
        find.byKey(const ValueKey('saved-filter-Regret over 500')),
        findsOneWidget,
      );
    });

    testWithDatabase('a chip puts its options on the sheet', (
      tester,
      db,
    ) async {
      final saved = SavedFiltersRepository(db);
      await saved.save(
        'Big regrets',
        const TransactionFilter(minAmount: 70000, feeling: Feeling.regret),
      );
      await open(tester, opener(db));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('saved-filter-Big regrets')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('filter-apply')));
      await tester.tap(find.byKey(const ValueKey('filter-apply')));
      await tester.pumpAndSettle();

      expect(result!.minAmount, 70000);
      expect(result!.feeling, Feeling.regret);
    });

    testWithDatabase('the cross of a chip deletes it', (tester, db) async {
      final saved = SavedFiltersRepository(db);
      await saved.save('Old', const TransactionFilter(feeling: Feeling.want));
      await open(tester, opener(db));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('saved-filter-Old')), findsOneWidget);

      await tester.tap(find.byTooltip('Delete this saved filter'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('saved-filter-Old')), findsNothing);
      expect(await saved.getAll(), isEmpty);
    });
  });
}
