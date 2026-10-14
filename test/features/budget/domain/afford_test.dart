import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/budget/domain/afford.dart';
import 'package:hishab/features/budget/domain/safe_to_spend.dart';

// 30,000 budget, 10,000 spent, 5,000 of bills to come, 10 days left: 15,000
// remains, 1,500 a day, nothing spent today.
const safe = SafeToSpend(
  budget: 3000000,
  spentBeforeToday: 1000000,
  spentToday: 0,
  upcomingBills: 500000,
  daysLeft: 10,
);

void main() {
  const balance = 5000000;

  test('fits in what is left for today', () {
    final c = affordCheck(price: 100000, safe: safe, totalBalance: balance);
    expect(c.verdict, AffordVerdict.fitsToday);
    expect(c.amount, 50000);
  });

  test('uses up days of the daily share, within the budget', () {
    final c = affordCheck(price: 400000, safe: safe, totalBalance: balance);
    expect(c.verdict, AffordVerdict.eatsDays);
    expect(c.days, 3);
    expect(c.amount, 110000);
  });

  test('breaks the budget', () {
    final c = affordCheck(price: 2000000, safe: safe, totalBalance: balance);
    expect(c.verdict, AffordVerdict.overBudget);
    expect(c.amount, 500000);
  });

  test('is over the budget by the whole price when it is already used up', () {
    const used = SafeToSpend(
      budget: 1000000,
      spentBeforeToday: 1200000,
      spentToday: 0,
      upcomingBills: 0,
      daysLeft: 5,
    );
    final c = affordCheck(price: 50000, safe: used, totalBalance: balance);
    expect(c.verdict, AffordVerdict.overBudget);
    expect(c.amount, 50000);
  });

  test('takes all the days when the share is under a poisha a day', () {
    const thin = SafeToSpend(
      budget: 1000,
      spentBeforeToday: 995,
      spentToday: 0,
      upcomingBills: 0,
      daysLeft: 10,
    );
    final c = affordCheck(price: 3, safe: thin, totalBalance: balance);
    expect(c.verdict, AffordVerdict.eatsDays);
    expect(c.days, 10);
  });

  test('is more than the accounts hold', () {
    final c = affordCheck(price: 6000000, safe: safe, totalBalance: balance);
    expect(c.verdict, AffordVerdict.overBalance);
    expect(c.amount, 1000000);
  });

  test('without a budget, only the accounts count', () {
    final ok = affordCheck(price: 100000, safe: null, totalBalance: 500000);
    expect(ok.verdict, AffordVerdict.fitsBalance);
    expect(ok.amount, 400000);

    final no = affordCheck(price: 100000, safe: null, totalBalance: 0);
    expect(no.verdict, AffordVerdict.overBalance);
    expect(no.amount, 100000);
  });
}
