import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/features/accounts/data/accounts_repository.dart';
import 'package:hishab/features/accounts/domain/account.dart';

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
