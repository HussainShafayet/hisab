import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/bazar/domain/shopping.dart';

ShoppingItem item(
  String name, {
  int quantity = 1,
  int? price,
  bool done = false,
}) => ShoppingItem(
  id: name.hashCode,
  name: name,
  quantity: quantity,
  price: price,
  isDone: done,
);

void main() {
  group('a line', () {
    test('costs the price of one times how many', () {
      expect(item('Rice', quantity: 5, price: 12000).total, 60000);
    });

    test('costs nothing without a price', () {
      expect(item('Salt', quantity: 3).total, 0);
    });
  });

  group('totalsOf', () {
    test('adds up everything and what is ticked', () {
      final totals = totalsOf([
        item('Rice', quantity: 2, price: 10000, done: true),
        item('Oil', price: 15000),
        item('Egg', quantity: 12, price: 1500, done: true),
        item('Salt'),
      ]);

      expect(totals.estimated, 20000 + 15000 + 18000);
      expect(totals.ticked, 20000 + 18000);
      expect(totals.tickedCount, 2);
      expect(totals.withoutPrice, 1);
    });

    test('is nothing for an empty list', () {
      final totals = totalsOf(const []);

      expect(totals.estimated, 0);
      expect(totals.tickedCount, 0);
    });
  });

  group('priceKey', () {
    test('ignores case, edges and extra spaces', () {
      expect(priceKey('  Basmati   RICE '), 'basmati rice');
    });
  });

  group('bazarNote', () {
    test('lists the names', () {
      expect(bazarNote([item('Rice'), item('Oil')]), 'Bazar: Rice, Oil');
    });

    test('is cut to fit', () {
      final note = bazarNote([item('x' * 40), item('y' * 40)], maxLength: 50);

      expect(note.length, 50);
      expect(note.endsWith('…'), isTrue);
    });
  });
}
