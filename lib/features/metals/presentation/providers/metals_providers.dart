import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/features/metals/data/metals_repository.dart';
import 'package:hishab/features/metals/domain/metals.dart';

final metalsRepositoryProvider = Provider<MetalsRepository>(
  (ref) => MetalsRepository(
    ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

final metalHoldingsProvider = StreamProvider<List<MetalHolding>>(
  (ref) => ref.watch(metalsRepositoryProvider).watchHoldings(),
);

/// The price of a gram of each metal, again after every change.
final gramPricesProvider = StreamProvider<GramPrices>(
  (ref) => ref.watch(metalsRepositoryProvider).watchPrices(),
);

/// What all the gold and silver is worth, as the prices stand.
final metalTotalsProvider = Provider<MetalTotals>((ref) {
  final holdings = ref.watch(metalHoldingsProvider).value ?? const [];
  final prices = ref.watch(gramPricesProvider).value ?? const GramPrices();
  return totalsOf(holdings, prices);
});
