import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/debts/domain/split.dart';

void main() {
  group('equalSplit', () {
    test('divides evenly between you and your friends', () {
      final split = equalSplit(120000, 3);

      expect(split.each, 30000);
      expect(split.mine, 30000);
    });

    test('keeps the poisha that do not divide with you', () {
      // ৳1,000.00 between 3 people: ৳333.33 each and 1 poisha left over.
      final split = equalSplit(100000, 2);

      expect(split.each, 33333);
      expect(split.mine, 33334);
      expect(split.mine + split.each * 2, 100000);
    });

    test('is all yours with no friends', () {
      final split = equalSplit(5000, 0);

      expect(split.mine, 5000);
    });
  });
}
