import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/investments/domain/investment.dart';
import 'package:hishab/features/investments/domain/investment_facts.dart';

InvestmentItem item({
  int id = 1,
  int putIn = 1000000,
  int profit = 0,
  int takenBack = 0,
  DateTime? started,
  bool closed = false,
  int? value,
}) => InvestmentItem(
  investment: Investment(
    id: id,
    name: 'Shop $id',
    note: '',
    startedOn: started ?? DateTime(2026, 4, 11),
    isClosed: closed,
    currentValue: value,
  ),
  putIn: putIn,
  profit: profit,
  takenBack: takenBack,
);

InvestmentEntry entry(InvestmentEntryKind kind, int amount, DateTime date) =>
    InvestmentEntry(
      id: amount,
      investmentId: 1,
      kind: kind,
      amount: amount,
      date: date,
      note: '',
    );

void main() {
  // 11 October 2026: 183 days after 11 April.
  final today = DateTime(2026, 10, 11, 14);

  group('factsOf', () {
    test('counts the days held and how much came back', () {
      final facts = factsOf(
        item(profit: 200000, takenBack: 100000),
        today: today,
      );
      expect(facts.heldDays, 183);
      expect(facts.recoveredPercent, 30);
    });

    test('works out a yearly rate from the return and the days', () {
      // ৳10,000 in, ৳2,000 profit, still worth ৳10,000: return 2,000 = 20%
      // in 183 days = 39% a year.
      final facts = factsOf(item(profit: 200000), today: today);
      expect(facts.annualPercent, 39);
    });

    test('profit a month and the months to get the money back', () {
      // ৳1,830 in 183 days is ৳300 a month; ৳8,000 not yet back.
      final facts = factsOf(item(profit: 183000), today: today);
      expect(facts.profitPerMonth, 30000);
      expect(facts.paybackMonths, 28);
    });

    test('no payback once the money is back', () {
      final facts = factsOf(
        item(profit: 800000, takenBack: 300000),
        today: today,
      );
      expect(facts.recoveredPercent, 110);
      expect(facts.paybackMonths, isNull);
    });

    test('says no rate in the first month or with no profit', () {
      final young = factsOf(
        item(profit: 100000, started: DateTime(2026, 10, 1)),
        today: today,
      );
      expect(young.annualPercent, isNull);
      expect(young.profitPerMonth, isNull);

      final nothing = factsOf(item(), today: today);
      expect(nothing.profitPerMonth, isNull);
      expect(nothing.paybackMonths, isNull);
    });

    test('a closed investment stops at its last line', () {
      final facts = factsOf(
        item(closed: true),
        today: today,
        lastLine: DateTime(2026, 6, 11),
      );
      expect(facts.heldDays, 61);
    });

    test('nothing put in has no percent', () {
      final facts = factsOf(item(putIn: 0), today: today);
      expect(facts.recoveredPercent, 0);
      expect(facts.annualPercent, isNull);
    });
  });

  group('profitByMonth', () {
    test('gives twelve months, oldest first, zero where nothing came', () {
      final result = profitByMonth([
        entry(InvestmentEntryKind.profit, 5000, DateTime(2026, 10, 3)),
        entry(InvestmentEntryKind.profit, 2000, DateTime(2026, 10, 9)),
        entry(InvestmentEntryKind.profit, 3000, DateTime(2026, 8, 20)),
        entry(InvestmentEntryKind.putIn, 99999, DateTime(2026, 10, 1)),
        entry(InvestmentEntryKind.profit, 777, DateTime(2025, 1, 1)),
      ], today: today);

      expect(result, hasLength(12));
      expect(result.first.month, DateTime(2025, 11));
      expect(result.last.month, DateTime(2026, 10));
      expect(result.last.amount, 7000);
      expect(result[result.length - 3].amount, 3000);
      expect(result[result.length - 2].amount, 0);
    });
  });

  group('arrangeInvestments', () {
    final items = [
      item(id: 1, putIn: 500000, profit: 100000),
      item(id: 2, putIn: 900000, profit: 20000, closed: true),
      item(id: 3, putIn: 200000, profit: 300000),
    ];

    test('keeps only the open or the closed ones', () {
      final open = arrangeInvestments(
        items,
        filter: InvestmentFilter.open,
        sort: InvestmentSort.newest,
      );
      expect(open.map((i) => i.investment.id), [3, 1]);

      final closed = arrangeInvestments(
        items,
        filter: InvestmentFilter.closed,
        sort: InvestmentSort.newest,
      );
      expect(closed.map((i) => i.investment.id), [2]);
    });

    test('best return first, then the most put in', () {
      final best = arrangeInvestments(
        items,
        filter: InvestmentFilter.all,
        sort: InvestmentSort.bestReturn,
      );
      expect(best.map((i) => i.investment.id), [3, 1, 2]);

      final most = arrangeInvestments(
        items,
        filter: InvestmentFilter.all,
        sort: InvestmentSort.mostPutIn,
      );
      expect(most.map((i) => i.investment.id), [2, 1, 3]);
    });
  });
}
