import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/notifications/alert_kind.dart';
import 'package:hishab/core/notifications/reminder_scheduler.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/domain/credit_card.dart';
import 'package:hishab/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/debts/presentation/providers/debts_providers.dart';
import 'package:hishab/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:hishab/features/reminders/domain/alerts.dart';
import 'package:hishab/features/settings/presentation/providers/settings_providers.dart';
import 'package:hishab/features/transactions/data/activity_queries.dart';
import 'package:hishab/features/zakat/data/zakat_settings_repository.dart';
import 'package:hishab/features/zakat/domain/zakat.dart';
import 'package:hishab/features/zakat/presentation/providers/zakat_providers.dart';

/// Notification ids: a recurring rule uses `rule * 10 + n`, a loan and a card
/// start from their own bases so the three never meet.
const _loanIdBase = 100000000;
const _cardIdBase = 200000000;
const _zakatId = 300000000;

/// The most loan reminders kept on the phone's schedule.
const _maxLoanReminders = 60;

DateTime _at(DateTime day) =>
    DateTime(day.year, day.month, day.day, reminderHour);

/// The notifications for loans as of [now]: one the day before and one on the
/// day a loan is due.
List<Reminder> loanRemindersFor(Iterable<DebtItem> items, DateTime now) {
  return [
    for (final planned in upcomingDebtReminders(
      items,
      now,
    ).take(_maxLoanReminders))
      Reminder(
        id:
            _loanIdBase +
            planned.item.debt.id * 2 +
            (planned.dayBefore ? 0 : 1),
        kind: AlertKind.loan,
        title: planned.dayBefore
            ? tr('Loan due tomorrow')
            : tr('Loan due today'),
        body: planned.item.debt.direction == DebtDirection.lent
            ? tr('{name} should pay you {amount}.', {
                'name': planned.item.debt.person,
                'amount': formatPoisha(planned.item.remaining),
              })
            : tr('You should pay {name} {amount}.', {
                'name': planned.item.debt.person,
                'amount': formatPoisha(planned.item.remaining),
              }),
        when: _at(planned.day),
      ),
  ];
}

/// The notifications for credit card bills as of [now]: for the next two bill
/// days of each card that has one, the day before and the day itself. The
/// amount is left out, since it changes with every purchase.
List<Reminder> cardRemindersFor(Iterable<Account> accounts, DateTime now) {
  final reminders = <Reminder>[];
  for (final account in accounts) {
    if (!account.isCreditCard || account.isArchived) continue;
    final dues = upcomingBillDues(account.billDueDay, now);
    for (var index = 0; index < dues.length; index++) {
      final due = dues[index];
      final before = DateTime(due.year, due.month, due.day - 1);
      final base = _cardIdBase + account.id * 4 + index * 2;
      final body = tr('Pay your {name} bill on time to avoid charges.', {
        'name': account.name,
      });
      reminders
        ..add(
          Reminder(
            id: base,
            title: tr('Credit card bill due tomorrow'),
            body: body,
            when: _at(before),
          ),
        )
        ..add(
          Reminder(
            id: base + 1,
            title: tr('Credit card bill due today'),
            body: body,
            when: _at(due),
          ),
        );
    }
  }
  return reminders;
}

/// The yearly zakat reminder, or none when no day was chosen: the next time
/// the day comes, at the usual hour.
List<Reminder> zakatReminderFor(ZakatSettings settings, DateTime now) {
  if (!settings.hasReminder) return const [];
  final day = nextZakatDay(settings.remindMonth!, settings.remindDay!, now);
  return [
    Reminder(
      id: _zakatId,
      kind: AlertKind.zakat,
      title: tr('Zakat day'),
      body: tr('Check how much zakat is due, under More > Zakat.'),
      when: _at(day),
    ),
  ];
}

/// Keeps everything that reminds up to date: adds what is due for the recurring
/// rules that add themselves, then sets the reminders of recurring items,
/// loans and credit card bills. It runs again when a rule or a loan changes,
/// when an account is saved (the form invalidates it), and when the app comes
/// back to the front (see `HishabApp`).
final reminderSyncProvider = FutureProvider<void>((ref) async {
  final rules = ref.watch(recurringRulesProvider).value;
  final debts = ref.watch(debtsProvider).value;
  // Runs again when the zakat day changes.
  ref.watch(zakatSettingsProvider);
  // And when an alert is switched on or off, its time changes, or the sound
  // changes (the sound belongs to the channel a reminder goes to).
  final (funSounds, dailyOn, dailyMinutes, wrappedOn) = ref.watch(
    preferencesProvider.select(
      (p) => (
        p.funSounds,
        p.dailyReminder,
        p.dailyReminderMinutes,
        p.wrappedAlert,
      ),
    ),
  );
  if (rules == null || debts == null) return;
  final repository = ref.read(recurringRepositoryProvider);
  final now = ref.read(clockProvider)();
  await repository.addAutomatic(now);
  final accounts = await ref.read(accountsRepositoryProvider).getAccounts();
  final db = ref.read(appDatabaseProvider);
  final today = dateOnly(now);
  final writtenToday =
      await db.entryCount(today, today.add(const Duration(days: 1))) > 0;
  final writtenThisMonth =
      await db.entryCount(monthStart(now), addMonths(monthStart(now), 1)) > 0;
  await ref.read(reminderSchedulerProvider).replaceAll([
    ...remindersFor(await repository.getRules(), now),
    ...loanRemindersFor(debts, now),
    ...cardRemindersFor(accounts, now),
    ...zakatReminderFor(
      ref.read(zakatSettingsProvider).value ?? ZakatSettings.defaults,
      now,
    ),
    if (dailyOn)
      ...dailyRemindersFor(
        now: now,
        minutes: dailyMinutes,
        writtenToday: writtenToday,
      ),
    if (wrappedOn) ...wrappedReminderFor(now, hasEntries: writtenThisMonth),
  ], funSounds: funSounds);
});
