import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/transactions/domain/note_suggestion.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

PastNote past(
  String note, {
  int amount = 5000,
  int? categoryId = 1,
  TransactionType type = TransactionType.expense,
}) => PastNote(note: note, type: type, amount: amount, categoryId: categoryId);

List<String> notes(List<PastNote> list) => [for (final p in list) p.note];

void main() {
  group('suggestNotes', () {
    test('offers the most written notes first when nothing is typed', () {
      final history = [
        past('Tea'),
        past('Lunch'),
        past('Lunch'),
        past('Rickshaw'),
        past('Lunch'),
        past('Rickshaw'),
      ];

      expect(notes(suggestNotes(history, '', type: TransactionType.expense)), [
        'Lunch',
        'Rickshaw',
        'Tea',
      ]);
    });

    test('looks for what was typed anywhere, starts first', () {
      final history = [
        past('Office lunch'),
        past('Office lunch'),
        past('Lunch with Rahim'),
        past('Dinner'),
      ];

      expect(
        notes(suggestNotes(history, 'lun', type: TransactionType.expense)),
        ['Lunch with Rahim', 'Office lunch'],
      );
    });

    test('counts the same note in other cases as one', () {
      final history = [past('lunch', amount: 100), past('Lunch', amount: 200)];

      final result = suggestNotes(history, '', type: TransactionType.expense);

      expect(result, hasLength(1));
      // The newest entry (first in the list) says what to offer.
      expect(result.single.note, 'lunch');
      expect(result.single.amount, 100);
    });

    test('does not offer what is already typed', () {
      final history = [past('Lunch'), past('Lunch with Rahim')];

      expect(
        notes(suggestNotes(history, 'lunch', type: TransactionType.expense)),
        ['Lunch with Rahim'],
      );
    });

    test('keeps incomes and expenses apart', () {
      final history = [
        past('Salary', type: TransactionType.income),
        past('Lunch'),
      ];

      expect(notes(suggestNotes(history, '', type: TransactionType.income)), [
        'Salary',
      ]);
    });

    test('stops at the limit and ignores blank notes', () {
      final history = [for (var i = 0; i < 9; i++) past('Item $i'), past('  ')];

      expect(
        suggestNotes(history, '', type: TransactionType.expense, limit: 3),
        hasLength(3),
      );
    });
  });
}
