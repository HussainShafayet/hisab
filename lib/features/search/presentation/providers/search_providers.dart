import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/features/transactions/domain/transaction_item.dart';
import 'package:hishab/features/transactions/presentation/providers/transactions_providers.dart';

/// Every transaction there is, read when the search is opened and again when
/// the data changes.
final searchTransactionsProvider =
    FutureProvider.autoDispose<List<TransactionItem>>((ref) {
      ref.watch(dataChangesProvider);
      return ref
          .watch(transactionsRepositoryProvider)
          .getBetween(DateTime(2000), DateTime(2200));
    });
