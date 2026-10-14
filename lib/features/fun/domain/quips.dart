import 'package:hishab/features/fun/domain/takka_mood.dart';

/// What Takka looks at to choose a thing to say.
class QuipInputs {
  const QuipInputs({
    required this.now,
    this.overdrawnCount = 0,
    this.budgetPercent,
    this.spentToday = 0,
  });

  final DateTime now;

  /// Accounts that hold less than nothing.
  final int overdrawnCount;

  /// How much of the month's budget is used, in percent. Null when there is
  /// no budget.
  final int? budgetPercent;

  /// Spent today, in poisha.
  final int spentToday;
}

/// A line for Takka to say, in English (it is translated when shown), and the
/// face to wear while saying it.
class Quip {
  const Quip(this.text, this.mood);

  final String text;
  final TakkaMood mood;
}

/// The lines by situation, most pressing first.
const _belowZero = [
  'Oops, an account is below zero. Did a payment go missing?',
  'Pocket says "ekhon taka nai!" Check the entries.',
  'Below zero? Either a bill ate it or an entry is missing.',
];

const _overBudget = [
  'The budget is crossed. Time to skip a few cha-singara.',
  'Budget paar! Let us go easy till the month ends.',
  'Over the limit. Even the rickshaw-wala is worried.',
];

const _nearBudget = [
  'Almost at the limit. Walk instead of taking a rickshaw today?',
  'The budget is nearly full. Cha at home, maybe?',
];

const _monthEnd = [
  'Month-end is near. Pocket is going thon-thon.',
  'A few days left. Be kind to your wallet.',
];

const _lateNight = [
  'Still awake? Even the bazar is asleep.',
  'Late-night spending? Sleep first, shop tomorrow.',
];

const _friday = [
  'Friday! Biryani day. Keep it inside the budget.',
  'Jummah Mubarak! A little mishti is fine, not a lot.',
];

const _quietDay = [
  'Nothing spent today. Your pocket is smiling.',
  'Zero spent today. Are you a saint, or did you forget to write?',
];

const _normal = [
  'Every taka you write down is a taka you can find.',
  'Small spends add up. Fuchka too!',
  'Write it down now, argue with yourself later.',
  'A little hishab every day keeps the tension away.',
];

/// Every line Takka can say, for the Bangla dictionary check.
const allQuips = [
  ..._belowZero,
  ..._overBudget,
  ..._nearBudget,
  ..._monthEnd,
  ..._lateNight,
  ..._friday,
  ..._quietDay,
  ..._normal,
];

/// Chooses what Takka says. Money trouble comes first, then the time of the
/// month, the hour and the day of the week, then a quiet day, then a general
/// line. The line changes every day, and [nudge] (a tap on Takka) moves to the
/// next one for the same situation.
Quip pickQuip(QuipInputs inputs, {int nudge = 0}) {
  final now = inputs.now;
  final percent = inputs.budgetPercent;
  final day = now.difference(DateTime(now.year)).inDays + nudge;

  Quip from(List<String> lines, TakkaMood mood) =>
      Quip(lines[day % lines.length], mood);

  if (inputs.overdrawnCount > 0) return from(_belowZero, TakkaMood.worried);
  if (percent != null && percent >= 100) {
    return from(_overBudget, TakkaMood.worried);
  }
  if (percent != null && percent >= 85) {
    return from(_nearBudget, TakkaMood.worried);
  }
  if (now.hour >= 23 || now.hour < 4) return from(_lateNight, TakkaMood.sleepy);
  if (now.day >= 26) return from(_monthEnd, TakkaMood.worried);
  if (now.weekday == DateTime.friday) return from(_friday, TakkaMood.happy);
  if (inputs.spentToday == 0) return from(_quietDay, TakkaMood.happy);
  return from(_normal, TakkaMood.happy);
}
