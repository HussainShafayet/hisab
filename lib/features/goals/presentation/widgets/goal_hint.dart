import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/goals/domain/goal.dart';
import 'package:intl/intl.dart';

/// One line on where a goal stands and what to do next: what is left, and,
/// with a day, how much to put aside each month to make it.
String goalHint(GoalWithSaved item, DateTime today) {
  if (item.isReached) return tr('Goal reached');
  final left = formatPoisha(item.left);
  final day = item.goal.targetDate;
  final days = item.daysLeft(today);
  if (day == null || days == null) {
    return tr('{amount} to go', {'amount': left});
  }
  final date = DateFormat('d MMM yyyy').format(day);
  if (days < 0) {
    return tr('Past {date} · {amount} to go', {'date': date, 'amount': left});
  }
  if (days <= 30) {
    return tr('{amount} to go by {date}', {'amount': left, 'date': date});
  }
  return tr('Put aside {amount} a month to reach it by {date}', {
    'amount': formatPoisha(item.perMonth(today) ?? item.left),
    'date': date,
  });
}
