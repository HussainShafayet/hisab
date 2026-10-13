import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/accounts/data/accounts_repository.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/domain/card_dollars.dart';
import 'package:hishab/features/accounts/domain/credit_card.dart';

final accountsRepositoryProvider = Provider<AccountsRepository>(
  (ref) => AccountsRepository(ref.watch(appDatabaseProvider)),
);

/// Accounts with balances. The argument is "include archived". `autoDispose`
/// stops listening to the database once no screen uses the provider.
final accountsProvider = StreamProvider.autoDispose
    .family<List<AccountWithBalance>, bool>(
      (ref, includeArchived) => ref
          .watch(accountsRepositoryProvider)
          .watchAccounts(includeArchived: includeArchived),
    );

/// One account, by id, for the edit form. Null if it does not exist.
final accountProvider = FutureProvider.autoDispose.family<Account?, int>(
  (ref, id) => ref.watch(accountsRepositoryProvider).getAccount(id),
);

/// The dollars spent, refunded and paid off on each credit card, with the
/// spending of the current month.
final cardDollarsProvider = StreamProvider.autoDispose<Map<int, CardDollars>>((
  ref,
) {
  final month = monthRange(ref.watch(clockProvider)());
  return ref
      .watch(accountsRepositoryProvider)
      .watchCardDollars(month.start, month.end);
});

/// The credit cards that are not archived, the ones that owe most first.
final creditCardsProvider = Provider.autoDispose<List<CreditCardStatus>>(
  (ref) => creditCardsOf(
    ref.watch(accountsProvider(false)).value ?? const [],
    dollars: ref.watch(cardDollarsProvider).value ?? const {},
  ),
);
