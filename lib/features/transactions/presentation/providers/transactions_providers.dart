import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/transactions/data/transactions_repository.dart';
import 'package:hishab/features/transactions/domain/add_transaction_options.dart';
import 'package:hishab/features/transactions/domain/transaction_item.dart';

final transactionsRepositoryProvider = Provider<TransactionsRepository>(
  (ref) => TransactionsRepository(ref.watch(appDatabaseProvider)),
);

/// Transactions in a date range, newest first. The range is a record, which
/// compares by value, so screens asking for the same range share one stream.
final transactionsInRangeProvider = StreamProvider.autoDispose
    .family<List<TransactionItem>, DateRange>(
      (ref, range) => ref
          .watch(transactionsRepositoryProvider)
          .watchBetween(range.start, range.end),
    );

/// Everything the add/edit form needs when it opens.
class TransactionFormData {
  const TransactionFormData({required this.options, this.source});

  final AddTransactionOptions options;

  /// The transaction being edited, or copied by "Duplicate". Null when adding.
  final TransactionItem? source;
}

typedef TransactionFormArgs = ({int? editId, int? duplicateId});

final transactionFormDataProvider = FutureProvider.autoDispose
    .family<TransactionFormData, TransactionFormArgs>((ref, args) async {
      final repository = ref.watch(transactionsRepositoryProvider);
      final sourceId = args.editId ?? args.duplicateId;
      final source = sourceId == null
          ? null
          : await repository.getTransaction(sourceId);
      if (sourceId != null && source == null) {
        throw const ValidationException('This transaction no longer exists.');
      }
      final options = await repository.loadAddOptions(
        now: ref.read(clockProvider)(),
        editing: source,
      );
      return TransactionFormData(options: options, source: source);
    });
