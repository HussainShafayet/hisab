import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:hishab/features/categories/presentation/providers/categories_providers.dart';
import 'package:hishab/features/transactions/domain/transaction_filter.dart';
import 'package:hishab/features/transactions/presentation/widgets/transaction_filter_sheet.dart';

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
}
