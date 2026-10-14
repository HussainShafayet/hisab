import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/features/investments/data/investments_repository.dart';
import 'package:hishab/features/investments/domain/investment.dart';

final investmentsRepositoryProvider = Provider<InvestmentsRepository>(
  (ref) => InvestmentsRepository(ref.watch(appDatabaseProvider)),
);

/// Every investment, oldest first, with its sums.
final investmentsProvider = StreamProvider<List<InvestmentItem>>(
  (ref) => ref.watch(investmentsRepositoryProvider).watchInvestments(),
);

/// The lines of one investment, newest first.
final investmentEntriesProvider = StreamProvider.autoDispose
    .family<List<InvestmentEntry>, int>(
      (ref, investmentId) =>
          ref.watch(investmentsRepositoryProvider).watchEntries(investmentId),
    );
