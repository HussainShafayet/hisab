import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/transactions/domain/feeling_summary.dart';
import 'package:hishab/features/transactions/domain/transaction_item.dart';

/// The wrapped of the month is offered in its last [wrappedLeadDays] days and
/// its first [wrappedTailDays] days of the next month.
const wrappedLeadDays = 4;
const wrappedTailDays = 5;

/// The month whose wrapped is on offer on [today], or null outside that time.
DateTime? wrappedMonthFor(DateTime today) {
  final day = dateOnly(today);
  if (day.day <= wrappedTailDays) return addMonths(monthStart(day), -1);
  if (daysInMonth(day) - day.day < wrappedLeadDays) return monthStart(day);
  return null;
}

/// A month in numbers, for the cards of the wrapped.
class MonthWrapped {
  const MonthWrapped({
    required this.month,
    required this.income,
    required this.expense,
    required this.entries,
    required this.spendFreeDays,
    required this.feelings,
    this.topCategory,
    this.topCategoryAmount = 0,
    this.biggest,
  });

  /// The first day of the month.
  final DateTime month;
  final int income;
  final int expense;

  /// How many entries were written.
  final int entries;
  final int spendFreeDays;
  final FeelingSummary feelings;

  /// The top-level category with the most spending, and what went to it.
  final String? topCategory;
  final int topCategoryAmount;

  /// The biggest single expense.
  final TransactionItem? biggest;

  /// Income less spending; below zero when more was spent than came in.
  int get saved => income - expense;

  /// Nothing was written.
  bool get isEmpty => entries == 0;

  /// What part of the spending went to the top category, from 0 to 1.
  double get topShare => expense == 0 ? 0 : topCategoryAmount / expense;
}

/// A playful title from where the most money went.
String wrappedPersona(String? topCategory) {
  final name = (topCategory ?? '').toLowerCase();
  if (name.contains('food')) return tr('The Foodie');
  if (name.contains('transport')) return tr('The Traveller');
  if (name.contains('shopping')) return tr('The Shopper');
  if (name.contains('bill')) return tr('The Responsible One');
  if (name.contains('health')) return tr('The Careful One');
  if (name.contains('education')) return tr('The Learner');
  if (name.contains('family') || name.contains('gift')) {
    return tr('The Generous One');
  }
  if (name.contains('festival')) return tr('The Festival Lover');
  if (name.contains('entertainment')) return tr('The Fun Seeker');
  return tr('The Balanced One');
}
