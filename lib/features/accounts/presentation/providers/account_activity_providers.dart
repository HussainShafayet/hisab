import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/accounts/domain/account_activity.dart';
import 'package:hishab/features/transactions/presentation/providers/transactions_providers.dart';

/// What came into and went out of each account in the current month.
final monthActivityProvider = Provider.autoDispose<Map<int, AccountActivity>>((
  ref,
) {
  final month = monthRange(ref.watch(clockProvider)());
  final items = ref.watch(transactionsInRangeProvider(month)).value ?? const [];
  return activityByAccount(items);
});
