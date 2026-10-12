import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/features/debts/data/debts_repository.dart';
import 'package:hishab/features/debts/domain/debt.dart';

final debtsRepositoryProvider = Provider<DebtsRepository>(
  (ref) => DebtsRepository(ref.watch(appDatabaseProvider)),
);

/// Every loan with how much was paid back, newest first.
final debtsProvider = StreamProvider.autoDispose<List<DebtItem>>(
  (ref) => ref.watch(debtsRepositoryProvider).watchDebts(),
);

/// One loan, by id. Null when it does not exist (any more).
final debtProvider = StreamProvider.autoDispose.family<DebtItem?, int>(
  (ref, id) => ref.watch(debtsRepositoryProvider).watchDebt(id),
);

/// The payments of one loan, newest first.
final debtPaymentsProvider = StreamProvider.autoDispose
    .family<List<DebtPayment>, int>(
      (ref, id) => ref.watch(debtsRepositoryProvider).watchPayments(id),
    );
