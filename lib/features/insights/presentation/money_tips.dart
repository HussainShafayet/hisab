import 'package:hishab/core/l10n/translator.dart';

/// Short, kind pieces of money advice, one a day. Called when shown, so the
/// language of the app applies.
List<String> moneyTips() => [
  tr(
    'Write each spend down the moment it happens. Memory forgets the small ones.',
  ),
  tr(
    'Pay yourself first: move some money to savings the day your salary comes.',
  ),
  tr('Before a big purchase, wait three days. If you still want it, buy it.'),
  tr(
    'Tea, snacks and rickshaw look small, but a month of them is a real number. Look at it once.',
  ),
  tr(
    'Keep one month of spending in a place you do not touch. That is your calm.',
  ),
  tr(
    'Pay the loan with the highest cost first, and never miss a small due date.',
  ),
  tr('A budget is a plan, not a punishment. Change it when life changes.'),
  tr('Check your balance once a week, not every hour.'),
  tr(
    'Ask "needed or wanted?" before paying. Mark the ones you regret and look at them on Sunday.',
  ),
  tr('Cook at home two more days a week and see what a month does.'),
  tr('Set a date for the credit card bill the day you get the statement.'),
  tr('Use the 50-30-20 idea as a start: needs, wants, savings. Make it yours.'),
  tr(
    'Small regular savings beat big rare ones. Even ৳100 a day is ৳36,500 a year.',
  ),
  tr(
    'Keep a note of who owes you. A kind reminder keeps friends and money both.',
  ),
  tr('Compare the price per kilo or per piece, not the price on the pack.'),
  tr('Review your subscriptions every three months. Cancel what you forgot.'),
  tr('Plan for Eid and big events early. Put a little aside each month.'),
  tr('Spend on health and learning without guilt. They pay back.'),
  tr(
    'When you get extra income, decide its job before it reaches your pocket.',
  ),
  tr('Back up your data. A phone can be lost; your records should not be.'),
];

/// The tip for [day]; [skip] moves on to the next ones.
String tipOfTheDay(DateTime day, {int skip = 0}) {
  final tips = moneyTips();
  final dayNumber = day.difference(DateTime(day.year)).inDays;
  return tips[(dayNumber + skip) % tips.length];
}
