import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/features/bazar/data/bazar_repository.dart';
import 'package:hishab/features/bazar/domain/shopping.dart';

final bazarRepositoryProvider = Provider<BazarRepository>(
  (ref) => BazarRepository(
    ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// The bazar list, what is still to buy first.
final bazarItemsProvider = StreamProvider<List<ShoppingItem>>(
  (ref) => ref.watch(bazarRepositoryProvider).watchItems(),
);

/// Remembered prices that match what is being typed. It follows the list, so a
/// price changed on the list shows up here too.
final priceSuggestionsProvider = FutureProvider.autoDispose
    .family<List<PriceSuggestion>, String>((ref, query) {
      ref.watch(bazarItemsProvider);
      return ref.watch(bazarRepositoryProvider).suggestions(query);
    });
