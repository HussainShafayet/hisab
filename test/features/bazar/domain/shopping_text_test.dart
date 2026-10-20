import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/bazar/domain/shopping.dart';

final now = DateTime(2026, 10, 11, 14, 30);

ShoppingItem item(
  String name, {
  int quantity = 1,
  int? price,
  bool done = false,
}) => ShoppingItem(
  id: name.hashCode,
  name: name,
  quantity: quantity,
  isDone: done,
  price: price,
);

void main() {
  group('shoppingListText', () {
    test('lists what is to buy with how many and what it costs', () {
      final text = shoppingListText([
        item('Rice', quantity: 2, price: 12000),
        item('Oil', price: 18000),
        item('Salt'),
      ], now);

      expect(
        text,
        'Bazar list · 11 Oct\n'
        '• Rice × 2 · ৳240.00\n'
        '• Oil · ৳180.00\n'
        '• Salt\n'
        'About ৳420.00',
      );
    });

    test('leaves out what is ticked, and its cost', () {
      final text = shoppingListText([
        item('Rice', price: 12000, done: true),
        item('Oil', price: 18000),
      ], now);

      expect(text, contains('Oil'));
      expect(text, isNot(contains('Rice')));
      expect(text, contains('About ৳180.00'));
    });

    test('says no total when nothing has a price', () {
      final text = shoppingListText([
        item('Salt'),
        item('Eggs', quantity: 12),
      ], now);

      expect(text, 'Bazar list · 11 Oct\n• Salt\n• Eggs × 12');
      expect(text, isNot(contains('About')));
    });

    test('is only the title for an empty list', () {
      expect(shoppingListText(const [], now), 'Bazar list · 11 Oct');
    });
  });
}
