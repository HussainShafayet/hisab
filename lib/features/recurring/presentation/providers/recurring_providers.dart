import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/notifications/reminder_scheduler.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/recurring/data/recurring_repository.dart';
import 'package:hishab/features/recurring/domain/recurring.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// The hour of the day a reminder is shown.
const reminderHour = 9;

final recurringRepositoryProvider = Provider<RecurringRepository>(
  (ref) => RecurringRepository(ref.watch(appDatabaseProvider)),
);

/// Every recurring rule, oldest first.
final recurringRulesProvider = StreamProvider<List<RecurringRule>>(
  (ref) => ref.watch(recurringRepositoryProvider).watchRules(),
);

/// The rules that have a day waiting to be added or skipped.
final dueItemsProvider = Provider.autoDispose<List<DueItem>>((ref) {
  final rules = ref.watch(recurringRulesProvider).value ?? const [];
  return dueItemsOf(rules, ref.read(clockProvider)());
});

/// The notifications to schedule for [rules] as of [now].
List<Reminder> remindersFor(Iterable<RecurringRule> rules, DateTime now) {
  return [
    for (final planned in upcomingReminders(rules, now))
      Reminder(
        id: planned.rule.id * 10 + planned.index,
        title: planned.rule.title,
        body: planned.rule.type == TransactionType.income
            ? tr('{amount} is expected today.', {
                'amount': formatPoisha(planned.rule.amount),
              })
            : tr('{amount} is due today.', {
                'amount': formatPoisha(planned.rule.amount),
              }),
        when: DateTime(
          planned.day.year,
          planned.day.month,
          planned.day.day,
          reminderHour,
        ),
      ),
  ];
}
