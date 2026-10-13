import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/features/tags/data/tags_repository.dart';
import 'package:hishab/features/tags/domain/tag.dart';
import 'package:hishab/features/transactions/domain/transaction_item.dart';
import 'package:hishab/features/transactions/presentation/providers/transactions_providers.dart';

final tagsRepositoryProvider = Provider<TagsRepository>(
  (ref) => TagsRepository(ref.watch(appDatabaseProvider)),
);

/// Every tag, the newest first. For choosing one on a transaction.
final tagsProvider = StreamProvider<List<Tag>>(
  (ref) => ref.watch(tagsRepositoryProvider).watchTags(),
);

/// Every tag with what was spent and received under it.
final tagSummariesProvider = StreamProvider<List<TagSummary>>(
  (ref) => ref.watch(tagsRepositoryProvider).watchSummaries(),
);

/// The transactions that carry one tag, newest first.
final tagTransactionsProvider = StreamProvider.autoDispose
    .family<List<TransactionItem>, int>(
      (ref, tagId) =>
          ref.watch(transactionsRepositoryProvider).watchByTag(tagId),
    );
