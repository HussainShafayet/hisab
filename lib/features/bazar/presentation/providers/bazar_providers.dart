import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/features/bazar/data/bazar_repository.dart';
import 'package:hishab/features/bazar/data/form_inbox_service.dart';
import 'package:hishab/features/bazar/data/form_inbox_gateway.dart';
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

/// Every remembered price, the newest first.
final rememberedPricesProvider = StreamProvider<List<RememberedPrice>>(
  (ref) => ref.watch(bazarRepositoryProvider).watchPrices(),
);

/// Remembered prices that match what is being typed. It follows the list and
/// the prices, so a change to either shows up here too.
final priceSuggestionsProvider = FutureProvider.autoDispose
    .family<List<PriceSuggestion>, String>((ref, query) {
      ref.watch(bazarItemsProvider);
      ref.watch(rememberedPricesProvider);
      return ref.watch(bazarRepositoryProvider).suggestions(query);
    });

final formInboxServiceProvider = Provider<FormInboxService>(
  (ref) => FormInboxService(
    db: ref.watch(appDatabaseProvider),
    repository: ref.watch(bazarRepositoryProvider),
    gateway: ref.watch(formInboxGatewayProvider),
  ),
);

/// What the form inbox did last: whether a sheet is linked, when it worked, or
/// what went wrong.
final formInboxStatusProvider = StreamProvider.autoDispose<FormInboxStatus>(
  (ref) => ref
      .watch(appDatabaseProvider)
      .settingsDao
      .watchAll()
      .map(FormInboxStatus.fromSettings),
);
