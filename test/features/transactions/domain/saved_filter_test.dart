import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/transactions/domain/feeling.dart';
import 'package:hishab/features/transactions/domain/saved_filter.dart';
import 'package:hishab/features/transactions/domain/transaction_filter.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

SavedFilter named(String name, {Feeling? feeling, int? min}) => SavedFilter(
  name: name,
  filter: TransactionFilter(feeling: feeling, minAmount: min),
);

void main() {
  group('a saved filter', () {
    test('keeps the options of the sheet through a round trip', () {
      const original = SavedFilter(
        name: 'Regret over ৳500',
        filter: TransactionFilter(
          type: TransactionType.expense,
          categoryId: 4,
          accountId: 2,
          minAmount: 50000,
          maxAmount: 900000,
          tagId: 7,
          feeling: Feeling.regret,
        ),
      );

      final back = decodeSavedFilters(encodeSavedFilters([original])).single;

      expect(back.name, 'Regret over ৳500');
      expect(back.filter.type, TransactionType.expense);
      expect(back.filter.categoryId, 4);
      expect(back.filter.accountId, 2);
      expect(back.filter.minAmount, 50000);
      expect(back.filter.maxAmount, 900000);
      expect(back.filter.tagId, 7);
      expect(back.filter.feeling, Feeling.regret);
    });

    test('does not keep the search text or the dates', () {
      final saved = SavedFilter(
        name: 'x',
        filter: TransactionFilter(
          query: 'tea',
          range: (start: DateTime(2026), end: DateTime(2027)),
          feeling: Feeling.need,
        ),
      );

      final back = decodeSavedFilters(encodeSavedFilters([saved])).single;

      expect(back.filter.query, '');
      expect(back.filter.range, isNull);
    });
  });

  group('reading what was saved', () {
    test('is empty for nothing, text that is not JSON, or a wrong shape', () {
      expect(decodeSavedFilters(null), isEmpty);
      expect(decodeSavedFilters(''), isEmpty);
      expect(decodeSavedFilters('not json {'), isEmpty);
      expect(decodeSavedFilters('{"a": 1}'), isEmpty);
    });

    test('skips an entry that is damaged and keeps the rest', () {
      final text =
          '[{"name": "Good", "feeling": "regret"}, {"name": ""}, 3, '
          '{"nope": true}, {"name": "Also good", "type": "banana", '
          '"minAmount": "lots"}]';

      final filters = decodeSavedFilters(text);

      expect(filters.map((f) => f.name), ['Good', 'Also good']);
      expect(filters.first.filter.feeling, Feeling.regret);
      // A value that means nothing is left out.
      expect(filters.last.filter.type, isNull);
      expect(filters.last.filter.minAmount, isNull);
    });
  });

  group('withSavedFilter', () {
    test('adds to the end', () {
      final all = withSavedFilter([named('a')], named('b'));

      expect(all.map((f) => f.name), ['a', 'b']);
    });

    test('replaces one with the same name, ignoring case', () {
      final all = withSavedFilter([
        named('Regret', feeling: Feeling.regret),
        named('b'),
      ], named('REGRET', feeling: Feeling.want));

      expect(all.map((f) => f.name), ['b', 'REGRET']);
      expect(all.last.filter.feeling, Feeling.want);
    });

    test('lets the oldest go beyond $maxSavedFilters', () {
      var all = <SavedFilter>[];
      for (var i = 0; i < maxSavedFilters + 3; i++) {
        all = withSavedFilter(all, named('f$i'));
      }

      expect(all, hasLength(maxSavedFilters));
      expect(all.first.name, 'f3');
      expect(all.last.name, 'f${maxSavedFilters + 2}');
    });
  });
}
