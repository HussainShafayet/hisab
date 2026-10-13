import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/app.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/core/widgets/app_snack_bar.dart';
import 'package:hishab/features/transactions/data/transactions_repository.dart';
import 'package:hishab/features/transactions/domain/transaction_input.dart';
import 'package:hishab/features/transactions/presentation/providers/transactions_providers.dart';

import '../helpers/fixtures.dart';
import '../helpers/form_actions.dart';
import '../helpers/pump_app.dart';

/// A repository whose saving fails with something that is not a rule of the
/// app, like a full disk would.
class _FailingTransactionsRepository extends TransactionsRepository {
  _FailingTransactionsRepository(super.db);

  @override
  Future<int> addTransaction(TransactionInput input, {int fee = 0}) =>
      throw StateError('disk is full');
}

void main() {
  testWithDatabase('an error that is not a rule is told in plain words and '
      'the form can be used again', (tester, db) async {
    useTallScreen(tester);
    final b = await seedBasics(db);
    await pumpAppWithDatabase(
      tester,
      db,
      overrides: [
        transactionsRepositoryProvider.overrideWith(
          (ref) =>
              _FailingTransactionsRepository(ref.watch(appDatabaseProvider)),
        ),
      ],
    );
    await openAddForm(tester);
    await typeAmount(tester, '500');
    await chooseCategory(tester, b.food);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const ValueKey('form-error'))).data,
      'Something went wrong. Please try again. (disk is full)',
    );
    // Not stuck: Save works again.
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save'))
          .onPressed,
      isNotNull,
    );
  });

  testWithDatabase('a message can be shown from outside any screen', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    await pumpAppWithDatabase(tester, db);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HishabApp)),
    );

    container
        .read(rootMessengerKeyProvider)
        .currentState!
        .showError('Something nobody caught');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Something nobody caught'), findsOneWidget);
  });
}
