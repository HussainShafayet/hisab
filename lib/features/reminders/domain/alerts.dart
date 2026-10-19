import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/notifications/alert_kind.dart';
import 'package:hishab/core/notifications/reminder_scheduler.dart';
import 'package:hishab/core/utils/date_labels.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/fun/domain/wrapped.dart';

/// Notification ids, apart from the ones in `reminder_sync.dart`.
const _dailyIdBase = 400000000;
const _wrappedIdBase = 500000000;
const _budgetNearId = 600000001;
const _budgetOverId = 600000002;
const _habitIdBase = 700000000;

/// The hour the wrapped alert comes, on the first day it is on offer.
const wrappedAlertHour = 9;

/// How many evenings ahead the daily reminder is put on the schedule. The app
/// sets them again every time it opens.
const dailyReminderDays = 7;

/// The budget alert comes at this percent of the month's budget, and again at
/// 100.
const budgetNearPercent = 85;

/// The habit alert: this many expenses of one category in [habitDays] days,
/// and again at every multiple of it.
const habitStep = 5;
const habitDays = 7;

/// The lines of the daily reminder, in English (translated when shown).
const dailyReminderLines = <String>[
  'Anything to write down today? Even ৳10 counts.',
  "Takka is hungry for today's entries.",
  'Quick one: what did you spend today?',
  'Two minutes now saves a month of guessing.',
  'Chai, rickshaw, bazar... did you write them down?',
  'Keep your streak alive: write down today.',
];

/// The id of the daily reminder of [day].
int dailyReminderId(DateTime day) => _dailyIdBase + day.month * 100 + day.day;

/// The daily reminders from [now] on: one each evening at [minutes] after
/// midnight, for [dailyReminderDays] days. Today's is left out when
/// [writtenToday] (nothing to remind about) or its time has passed.
List<Reminder> dailyRemindersFor({
  required DateTime now,
  required int minutes,
  required bool writtenToday,
}) {
  final today = dateOnly(now);
  final reminders = <Reminder>[];
  for (var i = 0; i < dailyReminderDays; i++) {
    final day = DateTime(today.year, today.month, today.day + i);
    if (i == 0 && writtenToday) continue;
    final when = DateTime(
      day.year,
      day.month,
      day.day,
      minutes ~/ 60,
      minutes % 60,
    );
    if (!when.isAfter(now)) continue;
    reminders.add(
      Reminder(
        id: dailyReminderId(day),
        kind: AlertKind.daily,
        title: tr('Takka is waiting'),
        body: tr(
          dailyReminderLines[(day.month * 31 + day.day) %
              dailyReminderLines.length],
        ),
        when: when,
      ),
    );
  }
  return reminders;
}

/// The alert that the wrapped of this month is ready, on the first day it is
/// on offer, or none when that moment has passed or nothing was written yet
/// this month ([hasEntries]).
List<Reminder> wrappedReminderFor(DateTime now, {required bool hasEntries}) {
  if (!hasEntries) return const [];
  final firstDay = daysInMonth(now) - wrappedLeadDays + 1;
  final when = DateTime(now.year, now.month, firstDay, wrappedAlertHour);
  if (!when.isAfter(now)) return const [];
  return [
    Reminder(
      id: _wrappedIdBase + now.year * 100 + now.month,
      kind: AlertKind.wrapped,
      title: tr('Your {month} wrapped is ready', {
        'month': monthLabel(monthStart(now)),
      }),
      body: tr('Swipe through your month with Takka.'),
      when: when,
    ),
  ];
}

/// How far a month's budget has got in alerts: nothing yet, nearly used, or
/// crossed. Each step is told once a month.
enum BudgetStep { none, near, over }

/// The step for [percent] of the budget used.
BudgetStep budgetStepOf(int percent) {
  if (percent >= 100) return BudgetStep.over;
  if (percent >= budgetNearPercent) return BudgetStep.near;
  return BudgetStep.none;
}

/// The alert for [step], or null for none. [percent] is how much is used,
/// [overBy] how much is spent above the limit (poisha).
Reminder? budgetAlertFor(
  BudgetStep step, {
  required int percent,
  required int overBy,
  required DateTime now,
}) {
  switch (step) {
    case BudgetStep.none:
      return null;
    case BudgetStep.near:
      return Reminder(
        id: _budgetNearId,
        kind: AlertKind.budgetNear,
        title: tr('Budget almost used'),
        body: tr(
          "{percent}% of this month's budget is gone. Takka is sweating.",
          {'percent': percent},
        ),
        when: now,
      );
    case BudgetStep.over:
      return Reminder(
        id: _budgetOverId,
        kind: AlertKind.budgetOver,
        title: tr('Budget crossed'),
        body: tr("You are {amount} over this month's budget. Wah wah wah...", {
          'amount': formatPoisha(overBy),
        }),
        when: now,
      );
  }
}

/// True when the [count]th expense of a category in the last [habitDays] days
/// is worth a word: every [habitStep]th one.
bool isHabit(int count) => count >= habitStep && count % habitStep == 0;

/// The habit alert for [category] after its [count]th expense in the last
/// [habitDays] days, [total] poisha in all.
Reminder habitAlertFor({
  required int categoryId,
  required String category,
  required int count,
  required int total,
  required DateTime now,
}) => Reminder(
  id: _habitIdBase + categoryId,
  kind: AlertKind.habit,
  title: tr('{category} again?', {'category': tr(category)}),
  body: tr(
    '{n} times in the last 7 days, {amount} so far. Takka is not judging.',
    {'n': count, 'amount': formatPoisha(total)},
  ),
  when: now,
);
